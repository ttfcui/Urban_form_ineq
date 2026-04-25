

capture program drop multi_msa_test
program define multi_msa_test

    qui duplicates r full_puma year if !missing(full_puma)
    if `r(unique_value)' < `r(N)' {
        * This is a case where the file contains a PUMA which straddles
        * multiple MSAs (identified in the IPUMS USA file). In practice, this
        * applies only to time-consistent PUMAs (of category "G3") that had to
        * cover up to half, if not all, of the remainder of the state not in MSA
        * borders. The multiple MSAs come from the PUMA including an exurban county or
        * two from multiple MSAs.
        duplicates tag full_puma year, gen(multi_msa)
        qui levelsof full_puma if multi_msa > 0
        display "WARNING: 2000/10 Consistent PUMAs straddling multiple MSAs:"
        display subinstr("`r(levels)'", "980", "", .)
        
        * It is a bit puzzling, without looking into source file, to know
        * which counties these people live in.
        * TODO: For now, we let the code proceed and drop them.
        drop if multi_msa > 0
        drop multi_msa
    }
end

capture program drop harmonize_1to1_data
program define harmonize_1to1_data
    syntax, sourcedir(string)

    tempfile matched_master
    rename st state
    multi_msa_test

    preserve
    keep if inrange(year, 2012, 2021)
    * These geographies are the reference period
    gen full_puma_matched = full_puma
    save `matched_master'

    restore, preserve
    keep if inrange(year, 2000, 2011)
    gen puma2k = mod(full_puma, 1e5)
    joinby state puma2k using `sourcedir'/PUMA_1to1_00to10.dta, unm(master)
    display "1-to-1 Match status on 2000s PUMAs:"
    tab year _merge

    gen full_puma_matched = state*1e5 + puma12
    * This condition separates out all the pre-aggregated PUMA geographies
    * in the source file, in which case we just carry them over
    replace full_puma_matched = full_puma if full_puma > 6.9e6
    drop _merge-PUMA00_Pop10

    append using `matched_master'
    save `matched_master', replace

    restore, preserve
    keep if year == 1990
    gen puma90 = mod(full_puma, 1e5)
    joinby state puma90 using `sourcedir'/PUMA_1to1_90to10.dta, unm(master)
    display "1-to-1 Match status on 1990s PUMAs:"
    tab year _merge

    gen full_puma_matched = state*1e5 + puma12
    replace full_puma_matched = full_puma if full_puma > 6.9e6
    drop _merge-PUMA10_Pop10

    append using `matched_master'
    save `matched_master', replace
    
    restore
    keep if year > 2021

    gen puma22 = mod(full_puma, 1e5)
    joinby state puma22 using `sourcedir'/PUMA_1to1_20to10.dta, unm(master)
    display "1-to-1 Match status on 2020s PUMAs:"
    tab year _merge

    gen full_puma_matched = state*1e5 + puma12
    replace full_puma_matched = full_puma if full_puma > 6.9e6
    drop _merge-PUMA10_Pop10
    order full_puma_matched, after(full_puma)
    * There is an issue on what happens if a 2010 PUMA got split into 2 or more
    * PUMAs. For now, we keep only 1 of those 2020 PUMAs in arbitrary ways...
    gen dup_flag = cond(!missing(full_puma_matched), full_puma_matched, full_puma)
    gsort dup_flag full_puma year
    duplicates r dup_flag year
    duplicates drop dup_flag year, force
    drop dup_flag
    
    append using `matched_master'
    sort full_puma year

end

capture program drop inc_explore_data_load
program define inc_explore_data_load
    syntax anything(name=persinc_fname), sourcedir(string) xwalkdir(string)
    
    tempfile persinc_mod
    use "`sourcedir'/`persinc_fname'", clear
    harmonize_1to1_data, sourcedir(`xwalkdir')
    save `persinc_mod'
    
    local hhinc_fname = regexr("`persinc_fname'", "^persinc", "hhinc")
    use "`sourcedir'/`hhinc_fname'", clear
    harmonize_1to1_data, sourcedir(`xwalkdir')
    
    foreach var of varlist persons_p-inc_var {
        rename `var' `var'_hh
    }
    merge 1:1 full_puma full_puma_matched year using `persinc_mod'
    sort year met2013 full_puma
    drop _merge
    
    * Because data is PUMA level, this is an implicit duplicates drop call
    * for visualizing only metros
    by year met2013: gen order = _n
    gen met_only = (order == 1)
    drop order
    
    decode met2013, gen(met_lab)
    replace met_lab = upper(regexr(met_lab, "-.+, ", ", "))
    order met_lab, after(met2013)
    
    egen panel_id = group(full_puma_matched full_puma), missing
    * This is the hard-coding we wanted to start with, if not for missing values
    replace panel_id = 1e6 + full_puma_matched if !missing(full_puma_matched)
    replace panel_id = 99e5 + panel_id if missing(full_puma_matched)
    order panel_id, before(year)
    
    label var full_puma "Original PUMA ID, listed in contemporaneous ACS data"
    label var full_puma_matched ///
        "Panel-based PUMA ID, based on closest 2010s PUMA to original"
    label var panel_id "Unique Panel ID"
    
    xtset panel_id year
    
end

capture program drop inc_explore_data_prep
program define inc_explore_data_prep
    syntax, [leads(integer 9)]
    
    assert abs(met_theil - (met_theil_btwn + met_theil_within)) <= 1e-5 ///
        if year > 1990
    sum met_theil met_theil_btwn met_theil_within if year == 1990
    
    * Change units of income measures in nominal dollars
    foreach measure of varlist incp?? inc_sd {
        replace `measure' = `measure'/1e3
        foreach def in _p _hh _p_hh {
            replace `measure'`def' = `measure'`def'/1e3
        }
    }
    replace group_mean_p = group_mean_p/1e3
    replace group_mean_p_hh = group_mean_p_hh/1e3
    
    * Specific time-series operator we use for long diffs
    local opr "F`leads'"

    * Long differences for second half analysis
    foreach var of varlist p90p50_p_hh-inc_sd_p_hh p90p50_p-inc_sd_p {
        gen `var'LD = `opr'.`var' - `var'
        label var `var'LD "`var', `leads' year long diff."
    }
    gen personsLD = log(`opr'.persons_p) - log(persons_p)
    gen householdsLD = log(`opr'.persons_p_hh) - log(persons_p_hh)
    label var personsLD "Resident growth, `leads' year long diff."
    label var householdsLD "Household growth, `leads' year long diff."    
    display "Years for which long differences were calculated:"
    tab year if !missing(personsLD)

    * Within-period gap between PUMA index and metro-wide index
    foreach var of varlist p90p50_p_hh-puma_theil_hh p90p50_p-puma_theil {
         local metvar = regexr("`var'", "_p", "")
         if regexm("`var'", "^puma") local metvar = regexr("`var'", "puma_", "met_")
         
         * _rel for _relative
         gen `var'_rel = `var' - `metvar'
         label var `var'_rel "`var', relative to metro index"
    }
    
end

capture program drop minimerge_group
program define minimerge_group
    syntax using [if]
    
    * A small function that wraps around the task of: when we have too many
    * MSAs, read a predetermined file that keeps only some MSAs grouped together
    * to show in a single graph. Depending on grouping variable, can be used
    * in different cases.
    preserve
    tempfile mini_group
    use `using', clear
    if "`if'" != "" keep `if'
    save `mini_group'
    
    restore
    merge n:1 met2013 using `mini_group', keep(3 4 5) update
    
    tab year
    tab year if !missing(full_puma_matched)

end

capture program drop IPUMS_inc_graph_specs
program define IPUMS_inc_graph_specs
    syntax anything(name=PUMA_def)

    /* We can edit this file, with global variables that pass through to the
       other exploratory figures, instead of changing arguments that pop up
       later. Of course, modify anything here with some caution.
    */
    

    * These are the set of time lengths over which we take long differences.
    * Availability is based on the reference years we have; we don't have it for
    * every year, but we do have e.g. 2012 = 2019 - 7.
    * The longer we go back, the more accuracy is maintained only through
    * using bigger time-consistent PUMAs (i.e. G3 geographies)
    global persistence_lag_yrs 7 14 19 29
    global correlates_lag_yrs 19 7 14

    * These are some measures of the inequality ratio, in contrast to the
    * distribution-level indices (so the 90/50 ratio is a measure of inequality
    * at the top).
    global ineq_ratio_measures p90p50_p p99p90_p p50p10_p
    global ineq_ratio_longdiffs = subinstr("$ineq_ratio_measures ", " ", "LD ", .)
    
    * Finally, set up what is the PUMA geography of interest (see details in
    * the data_load.do file). The bigger the number is, the larger the PUMAs are
    * in order to ensure time consistency.
    
    * The lack of annotation for G1 is the only unsystematic thing
    local PUMA_ref = "persinc" + regexr("`PUMA_def'", "^G1", "")
   
    global reference_file `PUMA_ref'_longitudinal_master
    
end


/* Preliminary data loading for later iterations */

* Definition of directories
do ../data_directory_info.do

project, uses($geo_xwalk_dir/PUMA_consistent_90to10.dta)
project, uses($geo_xwalk_dir/PUMA_consistent_00to10.dta)
project, uses($geo_xwalk_dir/PUMA_consistent_20to10.dta)
local fsuffix longitudinal_master
foreach data_type in persinc hhinc{
    project, uses($ineq_panel_dir/`data_type'_`fsuffix'.dta)
    project, uses($ineq_panel_dir/`data_type'G2_`fsuffix'.dta)
    project, uses($ineq_panel_dir/`data_type'G3_`fsuffix'.dta)

    foreach type in 2 {   // Any additional subsamples produced
        project, uses($ineq_panel_dir/`data_type'_subgrp`type'_`fsuffix'.dta)
        project, uses($ineq_panel_dir/`data_type'G2_subgrp`type'_`fsuffix'.dta)
        project, uses($ineq_panel_dir/`data_type'G3_subgrp`type'_`fsuffix'.dta)

    }
}

foreach geo_lvls in 1 2 3 99 {
foreach subsample_st in 2 1 {

* Now load the PUMA-year panel of income ineq statistics
* Dynamic updating of file names
local file_flag G`geo_lvls'
if `subsample_st' > 1 local file_flag "`file_flag'_subgrp`subsample_st'"

IPUMS_inc_graph_specs `file_flag'

inc_explore_data_load $reference_file, sourcedir($ineq_panel_dir) ///
    xwalkdir("$geo_xwalk_dir")
gen SmallMultipleGraphGroups = .
gen PooledAnalysisGraphGroups = .

preserve
foreach time_frame in 9 $correlates_lag_yrs {

    * Generates transformed and long difference variables based on the
    * number of years listed in local "time_frame"
    inc_explore_data_prep, leads(`time_frame')
    * This suffix indicates the interval over which differenced
    * variables are calculated
    local var_het merged_laggedby`time_frame'
    save $ineq_panel_dir/incineqG3_longitudinal_`var_het'.dta, replace
    
    restore, preserve
}

}
}
