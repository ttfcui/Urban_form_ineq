
/*    metrics are:
    -    Coefficient of Variance (CV): standard deviation divided by mean
    -    Variance of the logs: log-transform income before computing variance (sd = sqrt(variance))
    -    P90/P10
    -    P90/P50 vs P50/P10
    -    Lorenz curve
    -    Gini coefficient: difference between (A) area under equality line, and (B) area under Lorenz curve
*/



/* 1.  VARIABLE CONSTRUCTION IN DATA.  */

capture program drop primary_inc_construction
program define primary_inc_construction
    syntax anything(name=sourcedir)

    /*    drop children with no income    */
    drop if relate == 3 & inctot <= 0
    drop if relate == 4 & inctot <= 0
    drop if relate == 9 & inctot <= 0

    /*    personal income net of retirement    */
    replace inctot = . if inctot >= 9999998
    replace incss = . if incss == 99999
    replace incretir = . if incretir == 999999
    
    capture ds incsupp
    if _rc == 0 {
        * SSI for retirees not consistently separated in sample
        replace incsupp = . if incsupp == 99999
        egen retire_inc = rowtotal(incss incretir incsupp)
    }
    else {
        egen retire_inc = rowtotal(incss incretir)
        * Manually separate the SSI component of welfare?
        replace retire_inc = retire_inc + incwelfr if ///
            age >= 65 & incwelfr < 99999
    }
    
    gen persinc_net = inctot - retire_inc
    gen lpersinc_net = ln(persinc_net) if persinc_net != 9999999

    /*    total hh income net of retirement    */
    bys serial: egen retire_hh = total(retire_inc)
    gen hhinc_net = hhincome - retire_hh
    replace hhinc_net = . if hhincome == 9999999
    
    * Save labels for metro/state geographies to be appended
    capture label list MET2013
    if _rc == 0 {
        label save MET2013 STATEFIP using `sourcedir'/labels_temp.do, replace
    }
    
end


/* 2.  SUBPROCESSES FOR CONSTRUCTING INEQUALITY INDICES.  */

capture program drop ineq_index_within_loop
program define ineq_index_within_loop
    syntax varname [fweight/], byvar(string) [NOISILY]
    
    if "`noisily'" != "" {
        levelsof `byvar'
        local levels_stored "`r(levels)'"
    
        ineqdeco `varlist' [fw=`exp'], by(`byvar')
    }
    else {
        quietly levelsof `byvar'
        local levels_stored "`r(levels)'"
    
        quietly ineqdeco `varlist' [fw=`exp'], by(`byvar')        
    }

    foreach p of local levels_stored {
        matrix A1 = nullmat(A1) \ ( ///
            `r(gini_`p')', `r(ge1_`p')' ///
        )
    }
    matrix A2 = nullmat(A2) \ ( ///
            `r(gini)', `r(ge1)', `r(within_ge1)', `r(between_ge1)' ///
        )
    
end 

capture program drop subunit_gini_decomp
program define subunit_gini_decomp
    syntax varname [fweight/], [NOISILY]
    
    if "`noisily'" != "" {
        ineqdeco `varlist' [fw=`exp']
    }
    else {
        quietly ineqdeco `varlist' [fw=`exp']
    }
    sort persinc_net
    sum persinc_net if !missing(`varlist'), meanonly
    local orig_n = `r(N)'
    sum persinc_net if !missing(`varlist') [fw=`exp'], meanonly
    gen gini_contr = 2/(`r(N)'*`orig_n'*`r(mean)')*perwt*_n*(persinc_net -`r(mean)')
    if "`noisily'" != "" tabstat gini_contr, stat(sum)
    else quietly tabstat gini_contr, stat(sum)
    
end

capture program drop metro_stat_production
program define metro_stat_production
    syntax varname [fweight/], mainvar(string)
    
    /*  Calculations at the metro area level for all our
        inequality measures.
    */
    
    tabstat `varlist' [fw=`exp'], stat(sd var) save
    matrix IncV2 = r(StatTotal)'

    * Usage of custom package "fcollapse"
    fcollapse (first) `mainvar' year (count) persons=serial ///
        (mean) mean_inc=`varlist' (p10) incp10=`varlist' ///
        (p90) incp90=`varlist' (p99) incp99=`varlist' (p50) incp50=`varlist' ///
        [fw=`exp']
        
    gen p90p50 = incp90/incp50
    gen p90p10 = incp90/incp10
    gen p50p10 = incp50/incp10
    gen p99p90 = incp99/incp90

    * Here, we load in matrices of sub-metro indices that should
    * have been computed in a separate earlier function
    svmat A2, names(ind)
    svmat IncV2, names(vari)
    rename ind* (met_gini met_theil met_theil_within met_theil_btwn)
    rename vari* (inc_sd inc_var)
    
end


/* 3.  PRIMARY FUNCTIONS FOR ITERATING STATISTIC PRODUCTION.  */

capture program drop prep_microdata_geography
program define prep_microdata_geography
    syntax anything(name=fname) [if], sourcedir(string) ///
        [subarea(integer 1) xwalkdir(string)]

    use `sourcedir'/`fname' `if', clear
    sum year, meanonly
    local yrlab = cond(`r(max)' > 2009, `r(max)' - 2, `r(max)')
    local yrlab = floor(`yrlab'/10)*10

    * With the more complex geographies used in some cases, we invoke
    * a crosswalk we made matching PUMAs to bigger, more consistent custom PUMAs
    if `subarea' > 1 {
        display "Census geography to match: From year `yrlab'"

        local epoch = substr("`yrlab'", 3, .)
        if `yrlab' == 2010 local epoch = "00"
        local cons_name `xwalkdir'/PUMA_consistent_`epoch'to10.dta
        if "`xwalkdir'" == "" {
            display "Cannot continue function if crosswalk directory undefined!"
            exit
        }
        if `yrlab' == 2010 local puma_name puma12
        else if `yrlab' == 2000 local puma_name puma2k
        else if `yrlab' == 1990 local puma_name puma90
        else if `yrlab' == 2020 local puma_name puma22
        
        tempfile cons_file
        preserve
        
        use `cons_name', clear
        if `yrlab' != 2010 {
            gsort state `puma_name' -afact2
            drop puma12
        }
        else {
            gsort state `puma_name' -afact
            drop puma2k
        }
        duplicates drop state `puma_name', force
        rename (state `puma_name') (statefip puma)
        save `cons_file'
        
        restore
        merge n:1 statefip puma using `cons_file', keep(1 3)
        
    }

    * Per IPUMS, PUMAs are only unique when combined with the state FIPS code
    * The rest of this program offer different options for sub-metro geographies,
    * where the coarser the match, the more consistently we can define it
    * over many years of Census data.

    * By default, subarea == 1 takes the contemporary PUMA as the geography.
    * Smallest geography we have, and some (definitely not all) can be linked
    * consistently over 20 years or maybe 30. 
    gen full_puma = statefip*1e5 + puma

    * Subarea == 2 groups some PUMAs into "consistent PUMAs" that aggregates 2-3
    * PUMAs. Over 20+ years, these aggregate PUMAs don't change boundaries while
    * still representing just a small slice of the metro.
    if `subarea' == 2 {
        display "Setting up alternative geography: + small consistent PUMAs"
        replace full_puma = 7*1e6 + statefip*1e4 + CPUMA0010 if match_category == 7
    }
    * Subarea == 3 groups every PUMA into "consistent PUMA," even if the consistent
    * PUMA is very large. E.g. some states redrew PUMA borders so much over the years
    * that the consistent PUMAs remaining are just county groups.
    else if `subarea' == 3 {
        display "Setting up alternative geography: + all consistent PUMAs"
        replace full_puma = 98*1e5 + CPUMA0010 if !missing(CPUMA0010)
    }
    * TODO: Subarea == 4 is the coarsest geography, splitting metros into only two
    * parts: the area within the county containing the central city and everywhere
    * else outside that county.
    else if `subarea' == 4 {
        display "Setting up alternative geography: central vs outlying counties"
        
    }
    * A trivial definition: when we just want a metro area calculation over
    * a differently defined metro. There will be only one PUMA per metro.
    else if `subarea' == 9 {
        display "Skipping sub-metro area run:"
        replace full_puma = met2013
    }
    * Even more trivial definition: nothing is run separately by metro, and
    * the national indices are backed out. This is to see how much national
    * index is decomposable by metro (over the metros being sampled)
    else if `subarea' == 99 {
        display "National index calculations only:"
        replace met2013 = 1e7
        replace full_puma = met2013        
    }
    
    display "Overview of # submetro geographies:"
    unique full_puma
    if `subarea' > 1 {
        display "Counting only geographies altered from orig. PUMA:"
        unique full_puma if full_puma != statefip*1e5 + puma
    }

end


capture program drop ineq_stat_production
program define ineq_stat_production
    syntax varname [fweight/] [if/], mainvar(string) byvar(string)

    * Note that even though GINI and percentiles can be defined for
    * zero income values, we are dropping them in advance here
    keep if `varlist' > 0 & !missing(`varlist') & `if'
    tempfile metro_tab

    * TO COMPLETE: this is an incomplete function, in case we actually
    * want to compute the "Between" term for the Gini index. Alternatively,
    * can comment this out altogether to speed up script if Gini unnecessary.
    subunit_gini_decomp `varlist' [fw=`exp']

    foreach matname in A1 A2 IncV IncV2 {
        capture matrix drop `matname'
    }
    ineq_index_within_loop `varlist' [fw=`exp'], byvar(`byvar')

    preserve
    metro_stat_production `varlist' [fw=`exp'], mainvar(`mainvar')
    save `metro_tab'

    restore
    display "Metro has following PUMA IDs:"
    levelsof `byvar'
    local levels_stored "`r(levels)'"
    qui tabstat `varlist' [fw=`exp'], by(`byvar') stat(sd var) save
    local i = 1
    foreach p of local levels_stored {
        matrix IncV = nullmat(IncV) \ r(Stat`i')'
        local ++i
    }
    
    * Usage of custom package "fcollapse"
    fcollapse (first) st=statefip `mainvar' year (median) county=countyfip ///
        (count) persons_p = serial (mean) group_mean_p=`varlist' ///
        (p90) incp90_p=`varlist' (p50) incp50_p=`varlist' ///
        (p10) incp10_p=`varlist' (p99) incp99_p=`varlist' [fw=perwt], by(`byvar')

    gen p90p50_p = incp90_p/incp50_p
    gen p90p10_p = incp90_p/incp10_p
    gen p50p10_p = incp50_p/incp10_p
    gen p99p90_p = incp99_p/incp90_p

    svmat A1, names(ind)
    svmat IncV, names(vari)
    rename ind* (puma_gini puma_theil)
    rename vari* (inc_sd_p inc_var_p)

    merge n:1 `mainvar' year using `metro_tab', update
    
end

capture program drop ineq_metro_iteration
program define ineq_metro_iteration
    syntax varname [using/] [fweight/], mainvar(string) sourcedir(string)
    
    tempfile all_metros
    preserve
    qui levelsof `mainvar'
    foreach met_area in `r(levels)' {
        display "Processing metro coded: `met_area'"
        ineq_stat_production `varlist' if `mainvar' == `met_area' ///
            [fweight = `exp'], mainvar(`mainvar') byvar(full_puma)
        capture append using `all_metros'
        save `all_metros', replace
        restore, preserve
    }
    use `all_metros', clear
    * Bring back IPUMS custom labels for preserved geographies
    qui do `sourcedir'/labels_temp.do
    capture label val `mainvar' MET2013
    label val st STATEFIP

    order full_puma year `mainvar' st county, first
    sum year, meanonly
    local use_final = regexr("`using'", "_temp", "_`r(max)'_temp")
    save `use_final', replace

end

capture program drop ineq_production_call
program define ineq_production_call
    syntax anything(name=persinc_fname), metvar(string) xwalkdir(string) ///
        [subarea(integer 1)]

    tab `metvar'

    /*   Prepare for iterated calculation of person-level inequality measures */
    primary_inc_construction `xwalkdir'
    summarize inctot incss incretir retire_inc persinc_net if !missing(inctot) ///
        [fweight = perwt]
    ineq_metro_iteration persinc_net using `persinc_fname' [fweight = perwt], ///
        mainvar(`metvar') sourcedir(`xwalkdir')


    /*   household level data    */
    duplicates drop serial, force
    local hhinc_fname = regexr("`persinc_fname'", "persinc", "hhinc")

    /* Prepare for iterated calculation of household-level inequality measures */
    summarize hhincome retire_hh hhinc_net if !missing(hhincome) [fw = hhwt]
    ineq_metro_iteration hhinc_net using `hhinc_fname' [fweight = hhwt], ///
        mainvar(`metvar') sourcedir(`xwalkdir')
 
end

capture program drop append_full_data
program define append_full_data
    syntax anything(name=prefix), sourcedir(string) file90(string) outdir(string)

    /* Final touches to append data into full panel dataset */
    local files : dir "`sourcedir'" files "`prefix'*.dta"
    clear
    foreach fname of local files  {
        if !regexm("`fname'", "master.dta")  append using `sourcedir'/`fname'
    }
    sort met2013 full_puma year
    tab _merge
    drop _merge

    * Imputation of full 1990 metro data into metro-level stats
    sum persons-inc_var if year == 1990

    * Note that we *keep* the within-between decomposition from the original,
    * though now the decomposition isn't exact
    foreach var of varlist persons-met_theil inc_sd-inc_var {
        replace `var' = . if year == 1990
    }

    merge n:1 met2013 year using `sourcedir'/`file90', update
    sum persons-inc_var if year == 1990
    drop _merge

    save `outdir'/`prefix'longitudinal_master.dta, replace
    
end

capture program drop calc_subsample
program define calc_subsample
    syntax, [subsample_def(integer 1)]

    * By default, subsample == 1 does not drop anything, we tabulate
    * counts as needed.
    if `subsample_def' > 1 {
        display "Count sample in file before subsample restriction:"
        unique full_puma
    }

    * Subarea == 2 looks at college educated residents only (one definition
    * of a "gentrifier group")
    * TODO the codes MIGHT change between different years
    if `subsample_def' == 2 {
        display "Setting up alternative subsample: college educated"
        keep if educ >= 10
    }
    else if `subsample_def' > 1 {
        display "Subsample definition not yet implemented!"
    }
    
    display "Overview of geographies following subsample:"
    unique full_puma

end

/* FULL HIGH-LEVEL WORKFLOW  */


* Definition of directories
do ../data_directory_info.do

* Consistent PUMA crosswalk from IPUMS website
project, original($ipums_dir/IPUMS_ACS_2019.dta)
project, original($ipums_dir/top_100_metros_script.csv)
project, relies_on($geo_xwalk_dir/labels_temp.do)
project, uses($geo_xwalk_dir/PUMA_consistent_90to10.dta)
project, uses($geo_xwalk_dir/PUMA_consistent_00to10.dta)
project, uses($geo_xwalk_dir/PUMA_consistent_20to10.dta)


* First load in the top metros we want to process
import delimited $ipums_dir/top_100_metros_script.csv, enc(utf-8) varn(nonames) clear
levelsof v1, separate(,) local(main_mets)

* If run as part of the overall project command, make sure all
* the geographies are run in a loop together

foreach geo_lvls in 99 2 1 3 {
foreach subsample_st in 2 1 {
clear
* A Stata quirk, since the variables have to be in memory to be called
* in if command
set obs 2
gen met2013 = .

* Dynamic updating of file names
if `geo_lvls' == 1 local file_flag "inc"
else local file_flag "incG`geo_lvls'"

log using ./IPUMS_`file_flag'_calcs.log, replace
* We start off by taking note of every expanded microdata file
local files : dir "$ipums_dir" files "IPUMS*.dta"

foreach fname of local files {
    display char(10) + char(10) + "Now processing file:  `fname'"

    prep_microdata_geography `fname' if inlist(met2013, `main_mets'), ///
        subarea(`geo_lvls') sourcedir($ipums_dir) xwalkdir($geo_xwalk_dir)
    *), subarea(2) sourcedir(`sourcedir') xwalkdir(../Crosswalks)
    *), subarea(3) sourcedir(`sourcedir') xwalkdir(../Crosswalks)

    * Special filter for the 1990 file, which stacks separate samples
    count if sample == 199002
    if `r(N)' > 0 drop if sample == 199002
    
    * Wrapper for subsamples of people to calculate inequality indices on
    calc_subsample, subsample_def(`subsample_st')
    if `subsample_st' > 1 local file_flag "`file_flag'_subgrp`subsample_st'"
    
    * Look at program definition above to see this wraps both person-level
    * and household-level measures, with some flexibility in how
    * we define different output filenames.
    ineq_production_call $ipums_dir/pers`file_flag'_temp.dta, metvar(met2013) ///
        xwalkdir($geo_xwalk_dir)
    clear

    display char(10) + char(10) + "File processing complete:  `fname'" ///
        + char(10) + char(10) + char(10)
    * Repeat loop
    set obs 2
    gen met2013 = .

}


* One last run, using the slightly more accurate 1990 metro defs in
* The 1% metro file
clear
set obs 2
gen met2013 = .

local area90 9
if `geo_lvls' == 99 local area90 99
* CHECK: what is the filename here? Is "IPUMS" capitalized or not??
prep_microdata_geography ipums_5pct1pct_1990.dta if inlist(met2013, `main_mets'), ///
    subarea(`area90') sourcedir($ipums_dir) xwalkdir($geo_xwalk_dir)
keep if sample == 199002

calc_subsample, subsample_def(`subsample_st')

ineq_production_call $ipums_dir/met90_persinc_temp.dta, metvar(met2013) ///
    xwalkdir($geo_xwalk_dir)

* Need to drop this merge variable in advance (should be trivial anyway)
use $ipums_dir/met90_persinc_1990_temp.dta, clear
drop _merge
save, replace

use $ipums_dir/met90_hhinc_1990_temp.dta, clear
drop _merge
save, replace

clear
log c



/* Appending together a separate person-level dataset and household-level dataset */
append_full_data pers`file_flag'_, sourcedir($ipums_dir) ///
    file90(met90_persinc_1990_temp.dta) outdir($ineq_panel_dir)
append_full_data hh`file_flag'_, sourcedir($ipums_dir) ///
    file90(met90_hhinc_1990_temp.dta) outdir($ineq_panel_dir)

* Erase all the partial datasets, now that they're assembled
local files : dir "$ipums_dir" files "*inc*_temp.dta"
clear
foreach fname of local files  {
     erase $ipums_dir/`fname'
}

}
}


/* Verify results for project */

local fsuffix longitudinal_master
foreach data_type in persinc hhinc{
    project, creates($ineq_panel_dir/`data_type'_`fsuffix'.dta)
    project, creates($ineq_panel_dir/`data_type'G2_`fsuffix'.dta)
    project, creates($ineq_panel_dir/`data_type'G3_`fsuffix'.dta)
    project, creates($ineq_panel_dir/`data_type'G99_`fsuffix'.dta)

    foreach type in 2 {   // Any additional subsamples produced
        project, creates($ineq_panel_dir/`data_type'_subgrp`type'_`fsuffix'.dta)
        project, creates($ineq_panel_dir/`data_type'G2_subgrp`type'_`fsuffix'.dta)
        project, creates($ineq_panel_dir/`data_type'G3_subgrp`type'_`fsuffix'.dta)
        project, creates($ineq_panel_dir/`data_type'G99_subgrp`type'_`fsuffix'.dta)

    }
}
