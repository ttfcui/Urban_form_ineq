

/* PROGRAMS PROCESSING LINKING AND AGGREGATING MARKET DATA. */

capture program drop proc_distressed_markets
program define proc_distressed_markets
    syntax using/, sourcedir(string)
    
    * This imports data downloaded from Tim Bartik/Upjohn Institute,
    * "Economic Distress Webmap and Database"
    * This is the national data with multiple levels, but in particular
    * tract level data
    import excel "`sourcedir'/United States.xlsx", sheet("Tract") firstrow clear
    drop if TractPop <= 0
    describe CountyName-CensusTractID Distress*
    display "Relevant variables in new dataset:"
    list CountyName-CensusTractID Distress* in 1/3

    * We suspect the version downloaded as of 09/2025 used 2012-21 tract
    * definitions. A merge on the 2012 basis tract crosswalk to PUMAs works
    * pretty well.
    rename CensusTractID tractid_2010
    merge 1:1 tractid_2010 using `using'
    drop if _merge == 1
    
    qui unique SLLMPrimeAgeEmploymentRate, by(full_puma_matched) gen(puma_to_sllm)
    display "Tabulation of PUMAs by # Bartik SLLMs overlapped:"
    tab puma_to_sllm
    
    * The PUMA Rate is a weighted average over all 2012 tracts' denominators.
    * The SLLM Rate aggregates different rates for PUMAs overlapping
    * > 1 SLLM, based on share of PUMA pop in each SLLM.
    collapse (mean) SLLMPrime*Rate PUMAPrimeRate=TractPrimeAgeEmploymentRate ///
        (firstnm) num_SLLMs = puma_to_sllm ///
        [iw=TractPrimeageCivilian], by(full_puma_matched)
    * Note that full_puma_matched is a flexible definition: it maps to however
    * the PUMA were defined previously (maybe in time-consistent ways)
    label var SLLMPrime "Local Prime EPOP, across SLLMs"
    label var PUMAPrime "Local Prime EPOP, summed from tracts"

    * Generates distress "categories" in line with what Upjohn shows in
    * their maps.
    label def distress_cats 1 "[Close to] Fully Employed" 2 "Marginally Distressed" ///
        3 "Distressed" 4 "Severely Distressed"
    foreach dist_def in SLLM PUMA {
        gen `dist_def'_Distress_Ranking = cond( ///
            `dist_def'Prime >= 0.8, 1, cond(inrange(`dist_def'Prime, .765, 0.8), 2, ///
            cond(inrange(`dist_def'Prime, .723, 0.765), 3, ///
            cond(`dist_def'Prime < 0.723, 4, .))))
        label var `dist_def'_Distress_Rank "Distress Categories for `dist_def' measure"
        label val `dist_def'_Distress_Rank distress_cats
    }

    tab SLLM_Distress PUMA_Distress
    
end

capture program drop proc_buildable_area
program define proc_buildable_area
    syntax using/, sourcedir(string) xwalkdir(string)

    tempfile zipinfo
    * We first load in the ZIP-to-tract crosswalk we use, which is
    * the one invented by HUD. Note that even though it's many to many,
    * we only need the tract data to figure out PUMAs,
    * so most ZIPs will be matched to only 1 PUMA.
    import excel "`xwalkdir'/ZIP_TRACT_092019.xlsx", firstrow clear
    describe
    display "Relevant variables in new dataset:"
    list in 1/3

    rename tract tractid_2010
    * Merge in 2010 tract-to PUMA data
    merge n:1 tractid_2010 using `using'
    keep if _merge == 3
    * With this collapse operation, if a ZIP maps to multiple
    * tracts but they're all in one PUMA, the sum remains 1.
    collapse (sum) res_ratio tot_ratio, by(zip full_puma_matched)
    save `zipinfo'

    import delimited "`sourcedir'/zip.csv", clear stringc(1)
    rename geoid zip
    merge 1:n zip using `zipinfo'
    order full_puma_matched, after(zip)
    qui unique full_puma_matched, by(zip)
    tab _Unique
    display "Tabulation of PUMAs matched to each ZIP:"

    * For ZIPs that match predominantly to 1 PUMA but still has a tiny bit
    * straggling others, we drop those parts.
    drop if res_ratio <= 5e-3
    * And for ZIPs certified to be in multiple PUMAs, distribute their area
    * proportionally (some bias can be introduced here)
    foreach var in availableland buildableland {
        replace `var' = `var'*res_ratio if inrange(res_ratio, 5e-3, 1-5e-3)
        replace `var' = `var'/1e6
    }
    collapse (sum) *land, by(full_puma_matched)
    * Final percentage we care about ( ~= 1 - Lutz/Sand LU percentage)
    gen buildable_pct = 100*buildableland/availableland

    label var availableland "All landmass in PUMA, sq. km"
    label var buildableland "Landmass feasible for greenfield development in PUMA, sq. km"
    label var buildable_pct "Share of land in PUMA still buildable for greenfield"

end

capture program drop bsh_supply_aggregation
program define bsh_supply_aggregation
    syntax varlist

    foreach elasticity in `varlist' {

        * We calculate here two approximations for the aggregation,
        * based on demand assumptions on where people would locate
        * in metro. Because the measures use different weights, we sum
        * up weighted terms directly instead of weighing a collapse command.
        * For more details, see the formulas in the paper
        * at start of Section VI.
        gen def1_`elasticity'_num = occhu0*`elasticity'/(1 + `elasticity')
        gen def1_`elasticity'_den = occhu0/(1 + `elasticity')
        
        gen def2_`elasticity' = H_share_puma*`elasticity'
    }

    collapse (sum) def1_* def2_*, by(full_puma_matched)

    foreach elasticity in `varlist'{
        
        * Technically we only summed up the numerator and denominators
        * for the first aggregated supply def.
        gen def1_`elasticity' = def1_`elasticity'_num / def1_`elasticity'_den
        drop def1_`elasticity'_*
        order def1_`elasticity', before(def2_`elasticity')
        
        label var def1_`elasticity' "Inelastic-biased PUMA elasticity for: `elasticity'"
        label var def2_`elasticity' "Elastic-biased PUMA elasticity for: `elasticity'"

    }

    * A test is that the second definition overestimates how elastic aggregate
    * supply is (it's higher), because an assumption that people substitute
    * to least cost new development is baked in.
    sum

end


capture program drop proc_bsh_elasticities
program define proc_bsh_elasticities
    syntax using/, sourcedir(string) xwalkdir(string)

    tempfile tract00xw
    * We first load in a crosswalk by NHGIS that splits 2000 tracts
    * to the 2010 tracts fitting perfectly into a PUMA. Note that even though
    * it's many to many,
    * we only need the tract data to figure out PUMAs,
    * so most 2000 tracts will be matched to only 1 PUMA.
    import delimited "`xwalkdir'/nhgis_tr2000_tr2010.csv", clear stringc(2 4)
    * This takes out merges on 2010 tracts with 0 people, as well as PR tracts
    keep if wt_pop >= 1e-4 & substr(tr2010gj, 1, 3) != "G72"
    keep tr* wt_pop wt_hu
    rename (tr2000ge tr2010ge) (ctracts2000 tractid_2010)
    merge n:1 tractid_2010 using `using'

    * With this collapse operation, if a 2000 tract maps to multiple
    * 2010 tracts but they're all in one 2010 PUMA, the sum remains 1.
    collapse (sum) wt_*, by(ctracts2000 full_puma_matched)
    * Because tract-level elasticities are not counts, there's not a meaningful
    * sense of "allocating parts" of elasticities between PUMAs. Rather,
    * if a tract really straddles 2+ PUMAs sufficiently, we will count it in
    * the aggregation from tract to PUMA in every PUMA it intersects. 
    gsort ctracts2000 -wt_hu
    * The criterion for now is if at least a third is in separate PUMA
    gen assign_multi_puma = inrange(wt_hu, 0.34, 0.66)
    by ctracts2000: gen order = _n
    drop if order > 1 & assign_multi_puma == 0
    save `tract00xw'

    * Now let's load in the Baum-Snow/Han tract data, which seems to be
    * defined for 2000 tract boundaries as base
    use "`sourcedir'/gammas_hat_all.dta", clear
    describe cbdname-pctdis occhu0
    display "Relevant variables in new dataset:"
    list cbdname-pctdis occhu0 in 1/3

    joinby ctracts2000 using `tract00xw'
    * We need to redefine housing shares relative to a PUMA (what we're
    * aggregating over) instead of entire metros.
    bys full_puma_matched: egen H_puma_tot = total(occhu0)
    gen H_share_puma = occhu0/H_puma_tot

end


/* PROGRAMS PROCESSING LINKING 2010 TRACTS AND PUMA DEFS. */

capture program drop run_consistent_pumas
program define run_consistent_pumas
    syntax, sourcedir(string) [subarea(integer 1)]
    
    /* Prior to generating data that can be merged to data
       with time-consistent PUMAs (files "G2" and "G3"), need to
       ensure those PUMAs are the geographies getting aggregated over.
       (This is a duplicate of a program in block2puma_aggregation.do.)
   */
        
    preserve
    tempfile addl_aggregate
    * Note that this does not change based on year, because we're only
    * using the part of it that's a 2010 PUMA - time consistent PUMA xwalk.
    use "`sourcedir'/PUMA_consistent_00to10.dta", clear
    gen full_puma_matched = state*1e5 + puma12

    * This duplicates how we defined the time-consistent PUMAs in file:
    * IPUMS_inc_calcs.do.
    if `subarea' == 2 {
        display "Redefining alternative geography: + small consistent PUMAs"
        keep if match_category == 7
        gen full_puma_aggregated = 7*1e6 + state*1e4 + CPUMA0010
    }
    else if `subarea' == 3 {
        display "Redefining alternative geography: + all consistent PUMAs"
        gen full_puma_aggregated = 98*1e5 + CPUMA0010 if !missing(CPUMA0010)
    }
    else {
        restore
        display "No additional processing of PUMAs needed"
        exit
    }
    duplicates drop state puma12, force
    keep full_puma*
    save `addl_aggregate'

    restore
    merge n:1 full_puma_matched using `addl_aggregate'
    drop if _merge == 2
    drop _merge

    replace full_puma_matched = full_puma_aggregated if !missing(full_puma_aggregated)
    drop full_puma_aggregated
    display "Range of PUMA IDs, following imputation of time-consistent ones:"
    sum full_puma_matched, d
    
end

capture program drop run_puma_xwalk
program define run_puma_xwalk
    syntax, sourcedir(string) [xwalkdir(string) subarea(integer 1)]

    import delimited "`sourcedir'/geocorr2018_TractToPUMAs.csv", clear ///
        varn(1) rowr(3)
    display "Relevant variables in new dataset:"
    list county-stab afact in 1/3
    destring pop10 afact, replace
    assert afact >= 1
    gen tractid_2010 = county + subinstr(tract, ".", "", 1)
    gen full_puma = state + puma12
    destring full_puma, replace

    * Everything so far was calculated following 2010 PUMA boundaries,
    * so this change makes explicit which variable we should match with
    * in the income inequality data
    rename full_puma full_puma_matched

    * Up to now, the workflow closely resembles what we did in
    * block2puma_aggregation.do, so inserting run_consistent_pumas
    * here should work just like in there.
    run_consistent_pumas, sourcedir(`xwalkdir') subarea(`subarea')

end


/* EXECUTION OF CODE WORKFLOW HERE */

* Definition of directories
do ../data_directory_info.do

* Baum-Snow/Han elasticities data downloaded from academic site
project, original($mkt_rhs_dir/gamma_estimates_sep2023/gammas_hat_all.dta)
project, uses($geo_xwalk_dir/PUMA_consistent_00to10.dta)
* Lutz and Sand share of buildable land
project, original($mkt_rhs_dir/zip.csv)
* Custom crosswalk pulled from MCDC Geocorr site
project, original($geo_xwalk_dir/PUMA_matching/geocorr2018_TractToPUMAs.csv)
* Bartik/Upjohn distress data, downloaded from site
project, original("$mkt_rhs_dir/United States.xlsx")


foreach geolvl in 1 2 3 { 

tempfile tract10 distress_info buildable_info

* Iterate to generate time-consistent PUMAs aligned with
* "G2" or "G3" geographies.
run_puma_xwalk, sourcedir($geo_xwalk_dir/PUMA_matching) ///
    xwalkdir($geo_xwalk_dir) subarea(`geolvl')
save `tract10'

proc_distressed_markets using `tract10', sourcedir($mkt_rhs_dir)
save `distress_info'

proc_buildable_area using `tract10', sourcedir($mkt_rhs_dir) xwalkdir($geo_xwalk_dir/zip)
save `buildable_info'


** Output
proc_bsh_elasticities using `tract10', sourcedir($mkt_rhs_dir/gamma_estimates_sep2023) ///
    xwalkdir($mkt_rhs_dir)  // This is kept as ZIP in specific directory
bsh_supply_aggregation gamma01b_units_FMM gamma11b_units_FMM ///
    gamma01b_newunits_FMM gamma11b_newunits_FMM ///
    gamma01b_space_FMM gamma11b_space_FMM
    
merge 1:1 full_puma_matched using `buildable_info'
drop _merge
merge 1:1 full_puma_matched using `distress_info'
drop _merge
order def1_* def2_*, after(PUMA_Distress)

compress
describe
saveold $mkt_rhs_dir/PUMA_market_stats_G`geolvl'.dta, ///
    replace version(15)
}

project, creates($mkt_rhs_dir/PUMA_market_stats_G1.dta)
project, creates($mkt_rhs_dir/PUMA_market_stats_G2.dta)
project, creates($mkt_rhs_dir/PUMA_market_stats_G3.dta)
