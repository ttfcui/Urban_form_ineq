
capture program drop IPUMS_inc_graph_specs
program define IPUMS_inc_graph_specs
    syntax anything(name=PUMA_def)

    /* We can edit this file, with global variables that pass through to the
       other exploratory figures, instead of changing arguments that pop up
       later. Of course, modify anything here with some caution.
    */
    

    * This hackish global variable dictates file format for figures
    global fmt "png" // pdf
    
    * For a lot of our graphs, we are measuring change relative to an end period;
    * while the start period is allowed to vary depending on long term trends.
    * We pick 2019 as the last pre-COVID year, but can also shift this
    * as long we save the output files in separate directories.
    global endyr 2019
    local suff_yr = mod($endyr, 100)
    * This helps delineate the persistence plots in inequality outcomes.
    global endSuff "to`suff_yr'"
    
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
    * The possible values of PUMA_def are:   "G1" "G2" "G3"
    if "`PUMA_def'" == "G1" {
        global reference_file incineqG1_longitudinal_merged_laggedby
    }
    else if "`PUMA_def'" == "G2"  {
        global reference_file incineqG2_longitudinal_merged_laggedby    
    }
    else if "`PUMA_def'" == "G3" {
        global reference_file incineqG3_longitudinal_merged_laggedby        
    }
    
end



/* Preliminary data loading for later iterations */


local sourcedir "./puma_inc"
local puma_xwalk "./puma_inc"
tempfile grouping_xwalk

* Keep track of how to split up small multiple panels,
* for a larger dataset over MSAs
import excel "`puma_xwalk'/Top 100 metros in IPUMS.xlsx", firstrow clear
sum SmallMultiple, meanonly
local smMultLimit = `r(max)'

sum PooledAnalysis, meanonly
local pooledLimit = `r(max)'
keep met2013 *GraphGroups
save `grouping_xwalk'

IPUMS_inc_graph_specs G3



/* FIGURES FOR SECTION 1 */

capture program drop metro_ineq_dynamics
program define metro_ineq_dynamics
    syntax, outdir(string)
    
    /* Some exploratory analysis at metro level */
    
    sort met_only met2013 year
    preserve
    by met_only met2013: gen pop_growth_rate = persons/persons[1]*100
    by met_only met2013: gen hh_growth_rate = persons_hh/persons_hh[1]*100

    sort met_only year met2013
    local graph_opts xti("") yti("Metro-level Income Inequality") ///
        by(met_lab, legend(pos(6) col(2)))
        
    *
    twoway (connect met_theil year) if met_only, `graph_opts' name(met_main1, replace)
    graph export "`outdir'/metro_trends_main1.$fmt", as($fmt) replace
        
    twoway (connect incp90 year) (connect incp50 year) if met_only, ///
        `graph_opts' yti("000s USD, nominal") name(met_main2, replace)
    graph export "`outdir'/metro_trends_main2.$fmt", as($fmt) replace
        
    twoway (connect met_theil year) (connect p90p50 year, yaxis(2)) if met_only, ///
        `graph_opts' name(met_main3, replace)
    graph export "`outdir'/metro_trends_main3.$fmt", as($fmt) replace
    
    twoway (connect met_theil year) (connect p99p90 year, yaxis(2)) if met_only, ///
        `graph_opts' name(met_main31, replace)
    graph export "`outdir'/metro_trends_main31.$fmt", as($fmt) replace
        
    twoway (connect met_theil year) (connect incp90 year, yaxis(2)) if met_only, ///
        `graph_opts' name(met_main4, replace)
    graph export "`outdir'/metro_trends_main4.$fmt", as($fmt) replace

    *
    twoway (connect incp50 year) (connect incp10 year) if met_only, ///
        `graph_opts' name(met_bottom_ineq1, replace)
    graph export "`outdir'/metro_bottom_inequality1.$fmt", as($fmt) replace
    
    twoway (connect incp99 year) (connect incp90 year) if met_only, ///
        `graph_opts' name(met_bottom_ineq2, replace)
    graph export "`outdir'/metro_bottom_inequality2.$fmt", as($fmt) replace
        
    twoway (connect met_theil year) (connect p50p10 year, yaxis(2)) if met_only, ///
        `graph_opts' name(met_bottom_ineq3, replace)
    graph export "`outdir'/metro_bottom_inequality3.$fmt", as($fmt) replace

    *
    foreach var in inc_sd pop_growth_rate hh_growth_rate {
        if "`var'" == "pop_growth_rate" ///
            local graph_opts `graph_opts' ysc(r(80 240) axis(2))
            
        twoway (connect met_theil year) (connect `var' year, yaxis(2)) if met_only, ///
            `graph_opts' name(met_addl_`var', replace)    
        graph export "`outdir'/metro_trend_addl_`var'.$fmt", as($fmt) replace
    }

    *
    local graph_opts xti("") yti("Metro-level Income Inequality") ///
        by(met_lab, legend(pos(6) col(2)))
        
    twoway (connect met_theil year) (connect met_gini year, yaxis(2)) if met_only, ///
        `graph_opts' name(met_robust1, replace)
    graph export "`outdir'/metro_trend_robust1.$fmt", as($fmt) replace
        
    twoway (connect met_theil year) (connect met_theil_hh year, yaxis(2)) if met_only, ///
        `graph_opts' name(met_robust2, replace)
    graph export "`outdir'/metro_trend_robust2.$fmt", as($fmt) replace
        
    twoway (connect p90p50 year) (connect p90p50_hh year, yaxis(2)) if met_only, ///
        `graph_opts' yti("Ratio level") name(met_robust3, replace)
    graph export "`outdir'/metro_trend_robust3.$fmt", as($fmt) replace

    twoway (connect p99p90 year) (connect p99p90_hh year, yaxis(2)) if met_only, ///
        `graph_opts' yti("Ratio level") name(met_robust4, replace)
    graph export "`outdir'/metro_trend_robust4.$fmt", as($fmt) replace
    
end    


* We don't actually use the long diffs until a few sections down;
* This just sets a default dataset to use for plotting trends
local gap 9 
* We will iterate generating the set of small multiple dynamics graphs,
* and place each grouping of MSAs in their own directory.
forvalues i=1/`smMultLimit' {
    use `sourcedir'/$reference_file`gap', clear
    minimerge_group using `grouping_xwalk' if SmallMultipleGraphGroups == `i'
    local ilab = string(`i', "%02.0f")
    metro_ineq_dynamics, outdir(`figure_outdir'/metro_multiples_`ilab')
}


/* FIGURES FOR SECTION 2 A) */

capture program drop raw_persistence_plots
program define raw_persistence_plots
    syntax anything(name=diff_lengths), outdir(string)
    
    preserve
    foreach time_frame of numlist `diff_lengths' {
        inc_explore_data_prep, leads(`time_frame')
        local base_yr = $endyr - `time_frame'
        local base_suffix = string(mod(`base_yr', 100), "%02.0f")

        keep full_puma-county met_lab persons_p-puma_theil
        keep if !missing(full_puma_matched) & inlist(year, `base_yr', $endyr)
        drop full_puma
        reshape wide persons_p-puma_theil county, i(full_puma_matched) j(year)
        
        if `time_frame' == 7 local iter_measures puma_theil incp90_p $ineq_ratio_measures
        else local iter_measures puma_theil p90p50_p
        
        foreach measure of local iter_measures {
            twoway (scatter `measure'$endyr `measure'`base_yr') ///
                (function y=x, range(`measure'`base_yr') ///
                 lwidth(thick) lp(shortdash) color(red%60)), ///
            by(met_lab, legend(off)) xti("`measure', year `base_yr'") ///
            yti("`measure', year $endyr") ///
            name(puma_`measure'_`base_suffix'_$endSuff, replace)
            graph export "`outdir'/puma_`measure'_`base_suffix'to19.$fmt", as($fmt) replace
        }
        restore, preserve
    }
end


forvalues i=1/`smMultLimit' {
    use `sourcedir'/$reference_file`gap', clear
    minimerge_group using `grouping_xwalk' if SmallMultipleGraphGroups == `i'
    local ilab = string(`i', "%02.0f")
    sort panel_id year
    raw_persistence_plots $persistence_lag_yrs, ///
        outdir(`figure_outdir'/metro_multiples_`ilab')
}


    
/* FIGURES FOR SECTION 2 B) */

capture program drop metro_puma_decomp
program define metro_puma_decomp
    syntax, outdir(string)
    
    sort met_only year met2013
    local graph_opts xti("") yti("Metro-level Income Inequality") ///
        by(met_lab, legend(pos(6) col(2)))
        
    twoway (connect met_theil met_theil_btwn year) if met_only, ///
        `graph_opts' name(met_decomp1, replace)
    graph export "`outdir'/metro_trend_decomp1.$fmt", as($fmt) replace

    twoway (connect met_theil met_theil_within year) if met_only, ///
        `graph_opts' name(met_decomp2, replace)
    graph export "`outdir'/metro_trend_decomp2.$fmt", as($fmt) replace
        
    gen theil_btwn_share = met_theil_btwn/met_theil
    gen theil_within_share = met_theil_within/met_theil
    twoway (connect met_theil year) (connect theil_btwn_share year, yaxis(2)) if met_only, ///
        `graph_opts' name(met_decomp3, replace)
    graph export "`outdir'/metro_trend_decomp3.$fmt", as($fmt) replace
    
    
end

local gap 9 
forvalues i=1/`smMultLimit' {
    use `sourcedir'/$reference_file`gap', clear
    minimerge_group using `grouping_xwalk' if SmallMultipleGraphGroups == `i'
    local ilab = string(`i', "%02.0f")
    metro_puma_decomp, outdir(`figure_outdir'/metro_multiples_`ilab')
}



/* PRELUDE TO SECTION 3, SHOWING HH DEFINITION DIFFERENCES FROM INDIVIDUAL IN CROSS SECTION */

capture program drop puma_hh_robustness
program define puma_hh_robustness
    syntax [if], outdir(string)
    
    if "`if'" != "" keep `if'
    
    local graph_opts by(year, legend(off)) yti("Household-level measures") ///
        xti("Person-level measures")
    gen hh_filter = (inlist(mod(year, 10), 5, 0, 1, 2))
    * Differences in Theil index definition
    twoway (scatter puma_theil_hh puma_theil, msize(vsmall)) (function y=x, range(0.25 0.7)) ///
        if hh_filter, `graph_opts' name(hh_diff_theil, replace)
    * Differences in Gini index definition
    twoway (scatter puma_gini_hh puma_gini, msize(vsmall)) (function y=x, range(0.25 0.7)) ///
        if hh_filter, `graph_opts' name(hh_diff_gini, replace)
    * Differences in inequality at the top
    twoway (scatter p90p50_p_hh p90p50_p, msize(vsmall)) (function y=x, range(p90p50_p)) ///
        if hh_filter, `graph_opts' name(hh_diff_topineq, replace)
    twoway (scatter p99p90_p_hh p99p90_p, msize(vsmall)) (function y=x, range(p99p90_p)) ///
        if hh_filter, `graph_opts' name(hh_diff_1pctineq, replace)
    * Differences in inequality at the bottom
    twoway (scatter p50p10_p_hh p50p10_p, msize(vsmall)) (function y=x, range(p50p10_p)) ///
        if hh_filter, `graph_opts' name(hh_diff_bottomineq, replace)

end

local gap 9 
forvalues i=1/`pooledLimit' {
    use `sourcedir'/$reference_file`gap', clear
    minimerge_group using `grouping_xwalk' if PooledAnalysisGraphGroups == `i'
    local ilab = string(`i', "%02.0f")
    puma_hh_robustness if year <= $endyr, outdir(`figure_outdir'/pooled_plots_`ilab')
}


/* FIGURES FOR SECTION 3 A) */

capture program drop puma_ineq_plots
program define puma_ineq_plots
    syntax anything(name=ineq_ratioes), base_yr(integer) pop_growths(string) outdir(string)
    
    tabstat puma_theilLD `ineq_ratioes' if year==`base_yr', stat(n mean sd p1 q p99)

    qui sum puma_theilLD if year==`base_yr', d
    local ycoord_theil = `r(p99)'
    foreach var in `ineq_ratioes' `pop_growths' {
        qui reg puma_theilLD `var' if year==`base_yr', r
        local slope_`var' = "Slope: " + string(_b[`var'], "%5.3f")
        local se_`var' = "           (" + string(_se[`var'], "%5.3f") + ")"

        qui sum `var' if year==`base_yr', d
        local xcoord_`var' = `r(p95)'
    }

    foreach var in `ineq_ratioes' `pop_growths' {
        twoway (scatter puma_theilLD `var', msize(vsmall)) ///
            (lfit puma_theilLD `var', lwidth(thick) color(maroon%75)) if year==`base_yr', ///
            text(`ycoord_theil' `xcoord_`var'' "`slope_`var''" "`se_`var''", ///
                 box bcolor(white) size(medlarge)) legend(off) ///
            name(chgs_ineq_`var', replace)
        graph export "`outdir'/chgs_ineq_`base_yr'yr_`var'.$fmt", as($fmt) replace
    }

    * TODO HAVE TO SEND THIS OUT TO SEPARATE FUNCTION
    *twoway (scatter puma_theilLD p90p50_pLD) ///
    *    (lfit puma_theilLD p90p50_pLD, lwidth(thick) color(maroon%75)) if year==`base_yr', ///
    *    by(met_lab, legend(off)) name(chgs_ineq_bymet, replace)
    *graph export "`outdir'/chgs_ineq_`base_yr'yr_bymet.$fmt", as($fmt) replace

    * Unclear where to put these histograms in yet
    tokenize "`pop_growths'"
    local growth_dists `1'
    egen `growth_dists'_tier = xtile(`growth_dists') if year==`base_yr', by(met2013) n(3)
    twoway (kdensity p50p10_pLD) (kdensity p50p10_pLD if `growth_dists'_tier==1) ///
        (kdensity p50p10_pLD if `growth_dists'_tier==3) if year==`base_yr', ///
        name(morepop_topineq, replace)
    twoway (kdensity p90p50_pLD) (kdensity p90p50_pLD if  `growth_dists'_tier==1) ///
        (kdensity p90p50_pLD if `growth_dists'_tier==3) if year==`base_yr', ///
        name(morepop_bottomineq, replace)

end


* This is a double loop: run it for total number of binned pools, plus
* however many different time lengths we want to analyze
foreach time_frame in $correlates_lag_yrs {
    forvalues i=1/`pooledLimit' {
    use `sourcedir'/$reference_file`time_frame', clear
    minimerge_group using `grouping_xwalk' if PooledAnalysisGraphGroups == `i'
    local ilab = string(`i', "%02.0f")
    
    sort panel_id year
    local base_yr = $endyr - `time_frame'
    
    puma_ineq_plots $ineq_ratio_longdiffs, base_yr(`base_yr') ///
        pop_growths(householdsLD personsLD) outdir(`figure_outdir'/pooled_plots_`ilab')
    }
}


/* FIGURES FOR SECTION 3 B) */

capture program drop puma_ineq_spatial
program define puma_ineq_spatial
    syntax anything(name=plottypes), base_yr(integer) outdir(string)

    preserve
    foreach plotvar in `plottypes' {
        
        local relationship `plotvar'LD `plotvar'_rel
        gen plot_quadrants = cond(`plotvar'LD > 0 & `plotvar'_rel > 0, 1, ///
            cond(`plotvar'LD > 0 & `plotvar'_rel <= 0, 2, ///
            cond(`plotvar'LD <= 0 & `plotvar'_rel <= 0, 3, ///
            cond(`plotvar'LD <= 0 & `plotvar'_rel > 0, 4, .))))
        
        twoway (scatter `relationship' if plot_quadrants == 1) ///
            (scatter `relationship' if plot_quadrants == 3) ///
            (scatter `relationship' if plot_quadrants == 4) ///
            (scatter `relationship'  if plot_quadrants == 2) ///
            if year==`base_yr', xline(0) yline(0) legend(off) ///
            name(relative_plot_quad, replace)
        graph export "`outdir'/relative_plot_`plotvar'_quad.$fmt", as($fmt) replace

        qui reg `relationship' if year==`base_yr', r
        local slopeinfo = "Slope: " + string(_b[`plotvar'_rel], "%5.3f")
        local seinfo = "           (" + string(_se[`plotvar'_rel], "%5.3f") + ")"

        display "`slopeinfo'"
        display "`seinfo'"
        qui sum `plotvar'LD if year==`base_yr', d
        local ycoord = `r(p99)'
        qui sum `plotvar'_rel if year==`base_yr', d
        local xcoord = `r(p95)'

        twoway (scatter `relationship') ///
            (lfit  `relationship', lwidth(thick) color(maroon%75)) if year==`base_yr', ///
            text(`ycoord' `xcoord' "`slopeinfo'" "`seinfo'", ///
                 box bcolor(white) size(medlarge)) ///
            ytitle("`: var label `plotvar'LD'") legend(off) xline(0) yline(0) ///
            name(relative_plot_fit, replace) aspectratio(0.667)
        graph export "`outdir'/relative_plot_`plotvar'_fit.$fmt", as($fmt) replace
        
        keep if year == `base_yr'
        keep full_puma-county persons_p persons_p_hh `relationship' ///
            plot_quadrants match_category
        gen full_new = string(full_puma, "%07.0f")
        drop full_puma
        rename full_new full_puma
        order full_puma, first
        export delimited "`outdir'/relative_map_`plotvar'.csv", replace
        restore, preserve
    }

end


* Using one of the time frames defined for Section 3 A)
local gap 14
forvalues i=1/`pooledLimit' {
    use `sourcedir'/$reference_file`gap', clear
    minimerge_group using `grouping_xwalk' if PooledAnalysisGraphGroups == `i'
    local ilab = string(`i', "%02.0f")
    
    sort panel_id year
    inc_explore_data_prep, leads(`time_frame')
    local base_yr = $endyr - `time_frame'

    puma_ineq_spatial puma_theil $ineq_ratio_measures puma_theil_hh p50p10_p_hh, ///
        base_yr(`base_yr') outdir(`figure_outdir'/pooled_plots_`ilab')
}
/*
If we're interested in showing results as a (controlled) regression instead
reg puma_theilLD puma_theil_rel if year==2010, r
reg puma_theilLD puma_theil_rel incp50 if year==2010, r
reg puma_theilLD puma_theil_rel incp?0 if year==2010, r
*/


/* FIGURES FOR SECTION 4 ? */
/* NOTE: The "baseline results" explored in this section is on the G3 dataset
   (CPUMAs), even if the operations can run without a balanced panel.  */
by panel_id: gen event_time = year - year[1]
by panel_id: egen max_time = max(event_time)
tab max_time

local measure puma_theil
qui reghdfe `measure' c.event_time#i.full_puma_matched, ///
    absorb(full_puma_matched) vce(robust) resid
predict puma_resid, resid
collapse (count) panel_id (sd) puma_resid, by(full_puma_matched)

gen b = .
local sample = _N
forv i=1/`sample' {
    local puma_lvl = full_puma_matched[`i']
    capture local coeff = _b[`puma_lvl'.full_puma_matched#c.event_time]*10
    if _rc == 0 qui replace b = `coeff' in `i'
}

gsort -panel_id full_puma_matched
twoway (scatter puma_resid b if b > 0) (scatter puma_resid b if b <= 0)
gen b3 = (b > 0)
reg puma_resid b, r
reg puma_resid c.b##b3, r



