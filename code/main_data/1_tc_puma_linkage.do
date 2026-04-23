
capture program drop cpuma_prep_file
program define cpuma_prep_file
	syntax using/, [GET10]
	
	/* Takes the excel file of how consistent PUMAs created by IPUMS
	   match to real PUMAs, and make it more machine readable.
	*/
	
	import excel `using', clear firstrow
	* Option to extract the 2010 PUMAs that match as well
	if "`get10'" != "" local puma_ind "PUMA10"
	else local puma_ind "PUMA00"
	
	split `puma_ind'_List, parse(", ")
	* This backs out just which 2000/10 PUMAs match to CPUMAs.
	* TODO: If I understand the IPUMS algorithm, it shouldn't be possible
	* for a 2010 PUMA with a meaningful part taken from a 2000 PUMA
	* to be assigned into a different CPUMA as the 2000 part. But worth checking.
	drop `puma_ind'_List
	keep CPUMA0010-State_Name N_PUMA* `puma_ind'_Pop10 Error_Sum `puma_ind'_List*
	
	* New long dataset is unique at CPUMA level
	local puma_long `puma_ind'_List
	reshape long `puma_long', i(CPUMA0010) j(order)
	drop if `puma_long' == ""
	* This corrects for leading zeros Excel accidentally removed
	replace `puma_long' = "0" + `puma_long' if length(`puma_long') < 7
	drop if State_FIPS == "72" // Puerto Rico
	
	sort CPUMA0010 order
	
end

capture program drop puma_matching_xwalk_prep
program define puma_matching_xwalk_prep
	syntax using/, master_id(string) using_id(string)
	
	/* Starting from a crosswalk styled after the GEOCORR files,
	   clean and generate measures of "overlappingness with 2010 PUMA"
	   over the PUMAs we want to link.
	*/
	
	import delimited `using', varn(1) clear

	if regexm("`using'", "geocorr") {
		* If data are from MCDC geocorr, they add a label to the second row
		* below varnames, which is useful.
		foreach var of varlist *{
			local lbl = `var'[1]
			label var `var' "`lbl'"
		}
		drop in 1
	}
	destring *, replace

	drop if afact < 1e-3
	* Manually input varname of the 2010 PUMA boundaries, vs the "using"
	* one we're matching on.
	* The product here is a crude measure of the "share" that overlaps
	* between the PUMAs, relative to union of both PUMAs... assuming
	* boundary splitting is independent process
	bys state `master_id': egen max_component = max(afact)
	bys state `using_id': egen max_combined = max(afact*afact2)
	replace max_component = round(max_component, 0.01)
	replace max_combined = round(max_combined, 0.01)
	
end

capture program drop gen_match_classifications
program define gen_match_classifications
	syntax, reason_thres(real) [pop_thres(integer 400000)]
	
	/* Overall workflow for marking different PUMA linkages in terms
	   of match quality.
	   
	*/

	* First, check over which geography we're considering populations
	capture ds PUMA00_Pop10
	if _rc == 0 local pop10var PUMA00_Pop10
	else local pop10var PUMA10_Pop10
	
	gen match_category = .
	* Ideal match between PUMAs: borders are so similar that IPUMS algorithm
	* confirms there's 1-to-1 match
	replace match_category = 1 if N_PUMA10 == 1 & N_PUMA00 == 1
	* Not a 1-to-1 match, but usually a case where an outlying 2000 PUMA got
	* split into two due to continued population growth up to 2010
	replace match_category = 2 if missing(match_category) & N_PUMA00 == 1
	* "Reasonable" match between individual PUMAs for us, even if it were rejected 
	* by IPUMS algorithm: population overlap close enough as judged by max_combined param
	* (afact param filters out the minor components from other PUMAs)
	replace match_category = 3 if missing(match_category) & ///
		max_combined >= `reason_thres' & max_combined != 1 & afact > 0.5 & !missing(afact)
	* This doesn't mark a match between individual PUMAs, but notes which
	* CPUMAs from IPUMS correspond to a less populated part of city
	* (unlike, e.g. the whole core county or all the MSA periphery together)
	replace match_category = 7 if missing(match_category) & ///
		!(N_PUMA10 == 1 & N_PUMA00 == 1) & `pop10var' < `pop_thres'

	label def match_category ///
		1 "Ideal 1-to-1 match" 2 "N-to-1 match; 2010 PUMAs split from single 2000 PUMA" ///
		3 "Reasonable match that is not precise enough for IPUMS" ///
		7 "Flag for smaller area CPUMAs within metro: Pop < `pop_thres'", replace
	label val match_category match_category	

	* Verifying how the matches look in terms of geocorr match stats
	tabstat afact* if afact > 0.1, lab(32) by(match_category) stat(mean median sd)
	tabstat afact* if afact > 0.1 & missing(match_category), lab(32) stat(mean median sd)
	* To be continued with a count of unique PUMAs matched...
	
end

capture program drop puma90_to_cpuma_extended
program define puma90_to_cpuma_extended
	syntax using/, [cpuma_thres(real 0.95)]
	
	tempfile match_small
	drop if afact < 0.02 | afact2 < 0.02

	keep statefp10-puma90 afact afact2 PUMA10_Pop10 match_category
	save `match_small'

	* What we have to do is link a separate crosswalk that matched
	* 90 PUMAs directly to CPUMAs, instead of extrapolating these shares
	import delimited `using', clear
	bys statefip puma90: egen max_component = max(cpuma_share)
	unique statefip puma90 if max_component >= `cpuma_thres'
	replace cpuma0010 = . if max_component < `cpuma_thres'
	replace cpuma_share = . if max_component < `cpuma_thres'
	gsort statefip puma90 -cpuma_share
	duplicates drop statefip puma90, force
	rename puma90 puma
	gen puma90 = statefip*1e5 + puma
	
	merge 1:n puma90 using `match_small'
	* Have to revert PUMA to being a code that isn't already combined with state
	replace puma90 = mod(puma90, 1e5)
	
end

capture program drop puma22_to_cpuma_extended
program define puma22_to_cpuma_extended
	syntax , [cpuma_thres(real 0.95)]

    * A much more abbreviated version of the CPUMA filtering and linking,
	* because prior to this function we already defined a "share of puma22
	* in CPUMA variable", using population distribution.
	drop if afact < 0.02 | afact2 < 0.02
	
	* small_cpuma_share is equivalent of max_component in earlier function
	replace CPUMA0010 = . if small_cpuma_share < `cpuma_thres'
	replace small_cpuma_est = . if small_cpuma_share < `cpuma_thres'
	
	gsort state puma22 -small_cpuma_share puma12
	duplicates drop state puma22, force

	keep state-puma22 CPUMA0010 afact afact2 PUMA10_Pop10 match_category

end



/*
    EXECUTION OF CODE STARTS HERE
*/


* Definition of directories
do ../data_directory_info.do

local sourcedir $geo_xwalk_dir/PUMA_matching
local outdir $geo_xwalk_dir
local common_thres 0.85

*project, original(


/* REUSED DATA FROM IPUMS THAT FLAGS HOW TO MATCH PUMAS OVER TIME
   INTO TIME-CONSISTENT PUMAS */

tempfile cpuma_clean
cpuma_prep_file using `sourcedir'/CPUMA0010_summary.xls
rename PUMA00_List puma2kname
save `cpuma_clean'


/* ALL THE WORK MATCHING 2000 PUMAs TO 2010 PUMAs */

puma_matching_xwalk_prep using `sourcedir'/geocorr2014_PUMAs.csv, ///
	master_id(puma12) using_id(puma2k)

* What MCDC does is label only Missouri PUMAs in text, but leave the IDs
* for everything else. That said, we need to specifically modify out the
* textual labels with IDs
replace puma2kname = string(state*1e5 + puma2k, "%07.0f") if state==29
merge n:1 puma2kname using `cpuma_clean'
gsort -max_component N_PUMA00 -max_combined state puma12

* And the classification of which PUMAs are safe to match on goes here
gen_match_classifications, reason_thres(`common_thres')
* These are counts of unique matched PUMAs across specifications,
* which we track in spreadsheet "PUMA_matching_framework"
unique state puma12 if !missing(puma12), by(match_category)
unique state puma2k if !missing(puma2k), by(match_category)

preserve
gsort state puma12 -afact
keep if match_category <= 3
duplicates drop state puma12, force
tabstat afact*, lab(32) by(match_category) stat(mean median sd)
unique state puma12 if !missing(puma12), by(match_category)
unique state puma2k if !missing(puma2k), by(match_category)

keep state-puma2k afact afact2 PUMA00_Pop10 match_category
saveold `outdir'/PUMA_1to1_00to10.dta, replace


restore
* This is a simplified view of how to organize the PUMA-to-CPUMA dataset
drop if afact < 0.02 | afact2 < 0.02
keep state-puma2k afact afact2 CPUMA0010 PUMA00_Pop10 match_category
order CPUMA0010, after(puma2k)

unique state puma12 if !missing(puma12) & !missing(match_category)
unique state puma2k if !missing(puma2k) & !missing(match_category)
unique state puma12 if !missing(puma12) & !missing(CPUMA0010)
unique state puma2k if !missing(puma2k) & !missing(CPUMA0010)

saveold `outdir'/PUMA_consistent_00to10.dta, replace


/* MATCHING 1990 PUMAs TO 2010 PUMAs */

puma_matching_xwalk_prep using `sourcedir'/ipums1990_PUMAs.csv, ///
	master_id(pumace10) using_id(puma90)
gen puma10_merge = string(statefp10*1e5 + pumace10, "%07.0f")
merge n:1 puma10_merge using `cpuma_clean'

gen_match_classifications, reason_thres(`common_thres')

* NEW PORTION: 2010 PUMAs that aligned well with 2000 must now also
* satisfy this area overlap requirement for 1990 PUMAs
replace match_category = . if match_category <= 2 & ///
	max_combined < `common_thres' |  afact2 <= 0.5
* Same principle applies to matching 1990 PUMAs to CPUMAs, but only if
* most of the 90 PUMA is within those CPUMA boundaries
bys puma90 CPUMA0010: egen small_cpuma_est = sum(afact2)
bys puma90 CPUMA0010: egen small_cpuma_share = max(small_cpuma_est)
replace match_category = . if match_category == 7 & small_cpuma_share < `common_thres'


* Attrition more severe over this sample, but that's to be expected
unique state pumace10 if !missing(pumace10), by(match_category)
unique puma90 if !missing(puma90), by(match_category)

preserve
gsort state pumace10 -afact
keep if match_category <= 3
duplicates drop state pumace10, force
replace puma90 = mod(puma90, 1e5)

tabstat afact*, lab(32) by(match_category) stat(mean median sd)
unique state pumace10 if !missing(pumace10), by(match_category)
unique state puma90 if !missing(puma90), by(match_category)

keep statefp10 pumace10 puma90 afact* PUMA10_Pop10 match_category
rename (statefp10 pumace10) (state puma12)
saveold `outdir'/PUMA_1to1_90to10.dta, replace


restore
* Nuts and bolts of this process now in separate program
puma90_to_cpuma_extended using `sourcedir'/PUMA_consistent_90to10.csv,
keep statefip pumace10 puma90 cpuma0010 afact* PUMA10_Pop10 match_ca
rename (statefip pumace10 puma90 cpuma0010) (state puma12 puma90 CPUMA0010)
order puma12 puma90 CPUMA, after(state)

unique state puma12 if !missing(puma12) & !missing(match_category)
unique state puma90 if !missing(puma90) & !missing(match_category)
unique state puma12 if !missing(puma12) & !missing(CPUMA0010)
unique state puma90 if !missing(puma90) & !missing(CPUMA0010)

saveold `outdir'/PUMA_consistent_90to10.dta, replace


/* MATCHING 2020 PUMAs TO 2010 PUMAs */

puma_matching_xwalk_prep using `sourcedir'/geocorr2022_PUMAs.csv, ///
	master_id(puma12) using_id(puma22)
* In this file, Puerto Rico comes back + some trivial blocks for 2022
* PUMAs unmatched at edges.
drop if state == 72 | missing(puma12)
gen puma10_merge = string(state*1e5 + puma12, "%07.0f")
merge n:1 puma10_merge using `cpuma_clean'

gen_match_classifications, reason_thres(`common_thres')

* Repeat additional filter on 22-to-10 match quality, like with 1990.
replace match_category = . if match_category <= 2 & ///
	max_combined < `common_thres' |  afact2 <= 0.5
* Creation of this variable is necessary for remainder of code
bys puma22 CPUMA0010: egen small_cpuma_est = sum(afact2)
bys puma22 CPUMA0010: egen small_cpuma_share = max(small_cpuma_est)
replace match_category = . if match_category == 7 & small_cpuma_share < `common_thres'


* Attrition more severe over this sample, but that's to be expected
unique state puma12 if !missing(puma12), by(match_category)
unique state puma22 if !missing(puma22), by(match_category)

preserve
gsort state puma12 -afact
keep if match_category <= 3
duplicates drop state puma12, force

tabstat afact*, lab(32) by(match_category) stat(mean median sd)
unique state puma12 if !missing(puma12), by(match_category)
unique state puma22 if !missing(puma22), by(match_category)

keep state-puma22 afact* PUMA10_Pop10 match_category
saveold `outdir'/PUMA_1to1_20to10.dta, replace


restore
puma22_to_cpuma_extended
order puma12 puma22 CPUMA, after(state)

unique state puma12 if !missing(puma12) & !missing(match_category)
unique state puma22 if !missing(puma22) & !missing(match_category)
unique state puma12 if !missing(puma12) & !missing(CPUMA0010)
unique state puma22 if !missing(puma22) & !missing(CPUMA0010)

saveold `outdir'/PUMA_consistent_20to10.dta, replace



/* Pre-calculation step of matching METAREA codes to MET2013 ones
   This only needs to be done once for the 1990 data, where IPUMS
   didn't assign MET2013 to it in advance
*/

tempfile metro_xwalk
import delimited `sourcedir'/AM_MET2013_METAREA_xwalk.csv, clear
sort metarea_code met2013_label
by metarea_code: gen order = _n
by metarea_code: replace order = _N - order + 1 if inlist(metarea_code, 312, 664, 716)
list if order == 2

drop *_label
rename met2013_code met2013
reshape wide met2013, i(metarea_code) j(order)
rename (met2013*) (met2013 met2013_addl)
save `metro_xwalk'

local files : dir "$ipums_dir" files "IPUMS*1990.dta"

foreach fname of local files {
	use `sourcedir'/`fname', clear
	capture ds metarea_code
	if _rc != 0 {
		rename metarea metarea_code
		merge n:1 metarea_code using `metro_xwalk', keep(1 3)
		order met2013*, after(metarea_code)
		drop _merge
		save `sourcedir'/`fname', replace
	}
}
