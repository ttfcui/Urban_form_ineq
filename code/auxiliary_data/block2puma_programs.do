capture program drop constant_tract_crosswalk
program define constant_tract_crosswalk
    syntax using/, 
    
    import delimited `using', clear varn(1)
    * If data are from MCDC geocorr, they add a label to the second row
    * below varnames, which is useful.
    foreach var of varlist *{
        local lbl = `var'[1]
        label var `var' "`lbl'"
    }
    drop in 1
    destring pop10 afact, replace
    assert afact >= 1

    gen tr2010gj = "G" + substr(county, 1, 2) + "0" + substr(county, 3, .) + "0" + regexr(tract, "\.", "")
    gen full_puma = state + puma12
    destring full_puma, replace

    keep tr2010gj state puma12 full_puma
    
end

capture program drop nhgis_crosswalk_compilation
program define nhgis_crosswalk_compilation
    syntax, yr(integer) xwalkdir(string)
    
    * Before execution, the CSV file should have been loaded.
    preserve
    tempfile puma_info
    constant_tract_crosswalk using `xwalkdir'/geocorr2018_TractToPUMAs.csv
    save `puma_info'
    
    * Just a perfectionist streak - change codes to reflect renaming of Shannon Cty SD
    restore
    replace tr2010gj = regexr(tr2010gj, "G4601130", "G4601020")
    * Now merge to tract-PUMA dataset
    merge n:1 tr2010gj using `puma_info'
    tab _m if parea > 0 & !regexm(tr2010gj, "^G72")
    * Most likely the only tracts dropped here are ones with zero population,
    * or pertains to Puerto Rico
    keep if _m == 3

    local decade = floor(`yr'/10)*10
    local bgjoin bgp`decade'gj
    if `decade' == 2020 local bgjoin bg`decade'gj

    bys `bgjoin' puma12: egen puma_sum = total(wt_hu)
    by `bgjoin': egen max_share = max(puma_sum)
    by `bgjoin': egen max_share2 = max(wt_hu)
    sum max_s*, d

    qui unique state puma12, by(`bgjoin')
    tab _Unique

    drop if max_share <= 0.5 | puma_sum < 1e-3

    keep `bgjoin' - parea wt_pop wt_hh state-full_puma puma_sum
    gsort `bgjoin' -puma_sum -wt_hh

    preserve
    duplicates drop `bgjoin', force
    tabstat puma_sum wt_hh parea, stat(n mean sd q)
    restore
    rename `bgjoin' gisjoin
    
end

capture program drop run_puma_xwalk
program define run_puma_xwalk
    syntax, yr(integer) sourcedir(string)
    
    /*
    if `yr' == 1990 import delimited ///
        `sourcedir'/Longitudinal/nhgis_bgp1990_tr2010/nhgis_bgp1990_tr2010.csv, clear
    else if `yr' == 2000 import delimited ///
        `sourcedir'/Longitudinal/nhgis_bgp2000_tr2010/nhgis_bgp2000_tr2010.csv, clear
    else if `yr' == 2005 import delimited ///
        `sourcedir'/Longitudinal/nhgis_bgp2000_tr2010/nhgis_bgp2000_tr2010.csv, clear
    else if `yr' > 2018 import delimited ///
        `sourcedir'/Longitudinal/nhgis_bg2020_tr2010/nhgis_bg2020_tr2010.csv, clear
    else import delimited `sourcedir'/Contemporaneous/geocorr2014_BGtoPUMA.csv, clear varn(1)
    */
    local decade = floor(`yr'/10)*10
    display "processing year `yr'..."
    if `decade' < 2010 import delimited ///
        `sourcedir'/Longitudinal/nhgis_bgp`decade'_tr2010/nhgis_bgp`decade'_tr2010.csv, clear
    else if `decade' == 2020 import delimited ///
        `sourcedir'/Longitudinal/nhgis_bg`decade'_tr2010/nhgis_bg`decade'_tr2010.csv, clear
    else import delimited `sourcedir'/Contemporaneous/geocorr2014_BGtoPUMA.csv, clear varn(1)
    if `decade' != 2010 {
        nhgis_crosswalk_compilation, yr(`yr') xwalkdir(`sourcedir'/Longitudinal)
    }
    else {
        foreach var of varlist *{
            local lbl = `var'[1]
            label var `var' "`lbl'"
        }
        drop in 1
        destring pop10 afact, replace
        assert afact >= 1
        
        gen full_puma = state + puma12
        destring full_puma, replace
        rename afact puma_sum
        drop stab-pop10
        
        gen gisjoin = "G" + substr(county, 1, 2) + "0" + substr(county, 3, .) + ///
            "0" + regexr(tract, "\.", "") + bg
    }
    
    * Everything so far was calculated following 2010 PUMA boundaries
    * so this change makes explicit which variable we should match with
    * in the income inequality data
    rename full_puma full_puma_matched

    duplicates drop gisjoin state puma12, force

end

capture program drop run_consistent_pumas
program define run_consistent_pumas
    syntax, sourcedir(string) [subarea(integer 1)]
    
    /* Prior to generating data that can be merged to data
       with time-consistent PUMAs (files "G2" and "G3"), need to
       ensure those PUMAs are the geographies getting aggregated over.
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

capture program drop segregation_indices
program define segregation_indices
    syntax varlist(min=2) [if] [in], by(varname)
    
    
    // Mark sample
    marksample touse
    
    // Calculate area-level components
    keep if `touse'
    
    // For within-unit proportions
    egen unit_pop = rowtotal(`varlist')
    
    // Parse input variables
    tokenize `varlist'
    local geog `by'
    // Area-specific counts and shares
    local i = 1
    foreach var in `varlist' {
        by `geog', sort: egen area_group`i' = total(`var')
        local group`i' `var'
        local ++i
    }
    by `geog', sort: egen area_total = total(unit_pop)

    // Confirm total number of groups used in calculation
    local k = `i' - 1
    local varnum: word count `varlist'
    assert `varnum' == `k'

    forv i=1/`k' {
        // Calculate global proportions
        gen p_group`i' = area_group`i'/area_total

        // Calculate components for dissimilarity index
        gen group`i'_share = `group`i''/area_group`i'
    }
    
    if `k' == 2 {
        gen abs_diff = abs(group1_share - group2_share)
        local index_call d_index=abs_diff
    }
    else {
        display "More than 2 groups processed - cannot construct dissimilarity index"
    }
    
    forv i=1/`k' {
        // Calculate isolation components
        // This should be differentiated from an "exposure index" where
        // numerator `group`i'' is replaced with another group.
        gen iso_group`i' = group`i'_share * (`group`i''/unit_pop)

        // Calculate MI proportions (p_ig/p_i = N_ig/N_i)
        gen share_group`i' = `group`i''/(unit_pop)

        // Calculate mutual information components
        gen mi_term`i' = cond(`group`i'' > 0, ///
                            `group`i'' * ln(share_group`i'/p_group`i'), .)

    }
    // Wrap up sum for MI component
    egen mi_miss = rowmiss(mi_term*)
    * Tracts where a group is missing should be left out of calc
    egen mi_component = rowtotal(mi_term*) if mi_miss == 0
    replace mi_component = mi_component/area_total

    // Collapse to compute indices
    collapse (sum) `index_call' iso_group* mi_index=mi_component ///
        (first) area_total p_group*, by(`geog')
    
    // Calculate final dissimilarity index
    if `k' == 2 {
        replace d_index = 0.5 * d_index
        label var d_index "Dissimilarity Index"
    }
    
    // Label resulting variables
    label var area_total "Total persons/housing units in PUMA"
    forv i=1/`k' {
        label var p_group`i' "PUMA-wide share (Group `i')"
        label var iso_group`i' "Isolation Index (Group `i')"
    }

    // Normalize mutual information index (H-index)
    forv i=1/`k' {
        gen h_term`i' = p_group`i'*ln(p_group`i')
    }
    * Out of an abundance of caution
    egen h_miss = rowmiss(h_term*)

    egen h_normalization = rowtotal(h_term*) if h_miss == 0
    sum p_group? mi_index h_normalization, d
    replace mi_index = mi_index/(-1*h_normalization)
    drop h_normalization h_term* h_miss
    
    label var mi_index "Mutual Information Index"
    
    //    Herfindahl-Hirschman Index (HHI)
    forv i=1/`k' {
        gen hhi_`i' = (p_group`i') ^ 2
    }
    
    egen hhi = rowtotal(hhi_*)
    drop hhi_*
    label var hhi "Herfindahl-Hirschman Index"
    
end

