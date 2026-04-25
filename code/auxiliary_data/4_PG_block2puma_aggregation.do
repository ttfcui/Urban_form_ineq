/*    NEED TO SET SUBAREA (G1, G2, G2) AROUND "run_consistent_pumas". 
      THIS LINE REPEATS FOR ALL SEGREGATION INDICES.    */

set trace on
set tracedepth 3

/* MAIN CODE EXECUTION BELOW */

* Definition of directories
do ../data_directory_info.do
* Programs used in iterative script
do ./block2puma_programs.do

foreach yr in 1990 2000 2020 {
    local yrunit bgp`yr'_tr2010
    project, ///
        original($geo_xwalk_dir/Longitudinal/nhgis_`yrunit'/nhgis_`yrunit'.csv)
}
project, original($geo_xwalk_dir/Contemporaneous/geocorr2014_BGtoPUMA.csv)


local processed_years 1990 2000 /*2005*/ 2010 2012 2014 2017 2021 2022 2023


foreach geo_lvls in 1 2 3 {

local rhsdir $geo_rhs_dir/nhgis/nhgis0016_csv
local fsuffix _G`geo_lvls'.dta


//    var 01: sfr_detached
foreach yr of numlist `processed_years' {

    tempfile block_puma_xwalk values_`yr'

    run_puma_xwalk, yr(`yr') sourcedir($geo_xwalk_dir/BGtoPUMA)
    * Add subarea(2) or subarea(3) as we iterate through alternative geos
    run_consistent_pumas, sourcedir($geo_xwalk_dir) subarea(`geo_lvls')
    save `block_puma_xwalk'

    * TOM: The NHGIS tables can either be downloaded separately for each
    * variable of interest, or we can merge tables covering multiple variables
    * together.
    if `yr' == 1990 {
        import delimited `rhsdir'/nhgis0016_ds123_1990_blck_grp_598.csv, clear
        gen is_sfr_detached = ex2001
        egen not_sfr_detached = rowtotal(ex2002-ex2010)
    }
    else if `yr' == 2000 {
        import delimited `rhsdir'/nhgis0016_ds152_2000_blck_grp_090.csv, clear
        gen is_sfr_detached = g63001
        egen not_sfr_detached = rowtotal(g63002-g63010)
    }
    /*else if `yr' == 2005 {
        import delimited `rhsdir'/nhgis0016_ds195_20095_blck_grp.csv, clear
        gen is_sfr_detached = rqze002
        egen not_sfr_detached = rowtotal(rqze003-rqze011)
    }*/
    else if `yr' == 2010 {
        import delimited `rhsdir'/nhgis0016_ds176_20105_blck_grp.csv, clear
        gen is_sfr_detached = jsae002
        egen not_sfr_detached = rowtotal(jsae003-jsae011)
    }
    else if `yr' == 2012 {
        import delimited `rhsdir'/nhgis0016_ds191_20125_blck_grp.csv, clear
        gen is_sfr_detached = qyye002
        egen not_sfr_detached = rowtotal(qyye003-qyye011)
    }
    else if `yr' == 2014 {
        import delimited `rhsdir'/nhgis0016_ds206_20145_blck_grp.csv, clear
        gen is_sfr_detached = abhme002
        egen not_sfr_detached = rowtotal(abhme003-abhme011)
    }
    else if `yr' == 2017 {
        import delimited `rhsdir'/nhgis0016_ds233_20175_blck_grp.csv, clear
        gen is_sfr_detached = ah4wm002
        egen not_sfr_detached = rowtotal(ah4wm003-ah4wm011)
    }
    else if `yr' == 2021 {
        import delimited `rhsdir'/nhgis0016_ds254_20215_blck_grp.csv, clear
        gen is_sfr_detached = aotee002
        egen not_sfr_detached = rowtotal(aotee003-aotee011)
    }
    else if `yr' == 2022 {
        import delimited `rhsdir'/nhgis0016_ds262_20225_blck_grp.csv, clear    
        gen is_sfr_detached = aqtxe002
        egen not_sfr_detached = rowtotal(aqtxe003-aqtxe011)
    }
    else if `yr' == 2023 {
        import delimited `rhsdir'/nhgis0016_ds267_20235_blck_grp.csv, clear    
        gen is_sfr_detached = asuge002
        egen not_sfr_detached = rowtotal(asuge003-asuge011)
    }


    merge 1:n gisjoin using `block_puma_xwalk', 
    keep if _m == 3


    replace is_sfr_detached = is_sfr_detached*puma_sum
    replace not_sfr_detached = not_sfr_detached*puma_sum
    segregation_indices is_sfr_detached not_sfr_detached, by(full_puma)

    gen year = `yr'
    order year, after(full_puma)
    compress

    save `values_`yr'', replace
}


tempfile main

use `values_2023', clear
save `main'

foreach yr of numlist `processed_years' {
    use `values_`yr'', clear
    append using `main'
    save `main', replace
}
sort full_puma year


save "$geo_rhs_dir/segregation/segregation_sfr_detached`fsuffix'", replace


* Seems to a last testing step where I look at serial correlation of
* the segregation measures. Only works as intended with two groups.
/*    preserve
reshape wide d_index-hhi, i(full_puma) j(year)
corr d_index*
corr mi_index*
corr iso_group1*
corr iso_group2*
corr hhi*
restore    */




//    var 02: owner
foreach yr of numlist `processed_years' {

    tempfile block_puma_xwalk values_`yr'

    run_puma_xwalk, yr(`yr') sourcedir($geo_xwalk_dir/BGtoPUMA)
    * Add subarea(2) or subarea(3) as we iterate through alternative geos
    run_consistent_pumas, sourcedir($geo_xwalk_dir) subarea(`geo_lvls')
    save `block_puma_xwalk'

    * TOM: The NHGIS tables can either be downloaded separately for each
    * variable of interest, or we can merge tables covering multiple variables
    * together.
    if `yr' == 1990 {
        import delimited `rhsdir'/nhgis0016_ds123_1990_blck_grp_598.csv, clear
        
        gen is_owner = ez2001
        gen is_renter = ez2002
        
    }
    else if `yr' == 2000 {
        import delimited `rhsdir'/nhgis0016_ds152_2000_blck_grp_090.csv, clear
        
        gen is_owner = g50001
        gen is_renter = g50002
        
    }
    /*else if `yr' == 2005 {
        import delimited `rhsdir'/nhgis0016_ds195_20095_blck_grp.csv, clear
        
        gen is_owner = rp9e002
        gen is_renter = rp9e003
        
    }*/
    else if `yr' == 2010 {
        import delimited `rhsdir'/nhgis0016_ds176_20105_blck_grp.csv, clear
        
        gen is_owner = jrke002
        gen is_renter = jrke003
        
    }
    else if `yr' == 2012 {
        import delimited `rhsdir'/nhgis0016_ds191_20125_blck_grp.csv, clear
      
        gen is_owner = qx8e002
        gen is_renter = qx8e003    
    }
    else if `yr' == 2014 {
        import delimited `rhsdir'/nhgis0016_ds206_20145_blck_grp.csv, clear
      
        gen is_owner = abgxe002
        gen is_renter = abgxe003    
    }
    else if `yr' == 2017 {
        import delimited `rhsdir'/nhgis0016_ds233_20175_blck_grp.csv, clear
      
        gen is_owner = ah37e002
        gen is_renter = ah37e003    
    }
    else if `yr' == 2021 {
        import delimited `rhsdir'/nhgis0016_ds254_20215_blck_grp.csv, clear
      
        gen is_owner = aospe002
        gen is_renter = aospe003    
    }
    else if `yr' == 2022 {
        import delimited `rhsdir'/nhgis0016_ds262_20225_blck_grp.csv, clear    
        
        gen is_owner = aqsqe002
        gen is_renter = aqsqe003
    }
    else if `yr' == 2023 {
        import delimited `rhsdir'/nhgis0016_ds267_20235_blck_grp.csv, clear    
        
        gen is_owner = ass9e002
        gen is_renter = ass9e003
    }


    merge 1:n gisjoin using `block_puma_xwalk', 
    keep if _m == 3


    replace is_owner = is_owner*puma_sum
    replace is_renter = is_renter*puma_sum
    segregation_indices is_owner is_renter, by(full_puma)

    gen year = `yr'
    order year, after(full_puma)
    compress

    save `values_`yr'', replace
}


tempfile main

use `values_2023', clear
save `main'

foreach yr of numlist `processed_years' {
    use `values_`yr'', clear
    append using `main'
    save `main', replace
}
sort full_puma year


save "$geo_rhs_dir/segregation/segregation_owner`fsuffix'", replace


* Seems to a last testing step where I look at serial correlation of
* the segregation measures. Only works as intended with two groups.
/*    preserve
reshape wide d_index-hhi, i(full_puma) j(year)
corr d_index*
corr mi_index*
corr iso_group1*
corr iso_group2*
corr hhi*
restore    */





//    var 03: new <-- units built within 10 years prior to census year
foreach yr of numlist `processed_years' {

    tempfile block_puma_xwalk values_`yr'

    run_puma_xwalk, yr(`yr') sourcedir($geo_xwalk_dir/BGtoPUMA)
    * Add subarea(2) or subarea(3) as we iterate through alternative geos
    run_consistent_pumas, sourcedir($geo_xwalk_dir) subarea(`geo_lvls')
    save `block_puma_xwalk'

    * TOM: The NHGIS tables can either be downloaded separately for each
    * variable of interest, or we can merge tables covering multiple variables
    * together.
    if `yr' == 1990 {
        import delimited `rhsdir'/nhgis0016_ds123_1990_blck_grp_598.csv, clear
        
        egen is_new = rowtotal(ex7001-ex7003)    /*    1980 through 1990    */
        egen is_not_new = rowtotal(ex7004-ex7008)
        
    }
    else if `yr' == 2000 {
        import delimited `rhsdir'/nhgis0016_ds152_2000_blck_grp_090.csv, clear
        
        egen is_new = rowtotal(g67001-g67003)    /*    1990 through 2000    */
        egen is_not_new = rowtotal(g67004-g67009)
        
    }
    /*else if `yr' == 2005 {
        import delimited `rhsdir'/nhgis0016_ds195_20095_blck_grp.csv, clear
        
        egen is_new = rowtotal(rq2e002-rq2e003)    /*    2000 through 2009    */
        egen is_not_new = rowtotal(rq2e004-rq2e010)
        
    }*/
    else if `yr' == 2010 {
        import delimited `rhsdir'/nhgis0016_ds176_20105_blck_grp.csv, clear
        
        egen is_new = rowtotal(jsde002-jsde003)    /*    2000 through 2010    */
        egen is_not_new = rowtotal(jsde004-jsde010)
        
    }
    else if `yr' == 2012 {
        import delimited `rhsdir'/nhgis0016_ds191_20125_blck_grp.csv, clear
        
        egen is_new = rowtotal(qy1e002-qy1e003)    /*    2000 through 2012    */
        egen is_not_new = rowtotal(qy1e004-qy1e010)
    }
    else if `yr' == 2014 {
        import delimited `rhsdir'/nhgis0016_ds206_20145_blck_grp.csv, clear
      
        egen is_new = rowtotal(abhpe002-abhpe003)    /*    2000 through 2014    */
        egen is_not_new = rowtotal(abhpe004-abhpe010)    
    }
    else if `yr' == 2017 {
        import delimited `rhsdir'/nhgis0016_ds233_20175_blck_grp.csv, clear
      
        egen is_new = rowtotal(ah4ze002-ah4ze003)    /*    2010 through 2017    */
        egen is_not_new = rowtotal(ah4ze004-ah4ze011)
    }
    else if `yr' == 2021 {
        import delimited `rhsdir'/nhgis0016_ds254_20215_blck_grp.csv, clear
      
        egen is_new = rowtotal(aothe002-aothe003)    /*    2010 through 2021    */
        egen is_not_new = rowtotal(aothe004-aothe011)    
    }
   else if `yr' == 2022 {
        import delimited `rhsdir'/nhgis0016_ds262_20225_blck_grp.csv, clear    
        
        egen is_new = rowtotal(aqt0e002-aqt0e003)    /*    2010 through 2022    */
        egen is_not_new = rowtotal(aqt0e004-aqt0e011)
    }
    else if `yr' == 2023 {
        import delimited `rhsdir'/nhgis0016_ds267_20235_blck_grp.csv, clear    
        
        egen is_new = rowtotal(asuje002-asuje003)    /*    2010 through 2023    */
        egen is_not_new = rowtotal(asuje004-asuje011)
    }


    merge 1:n gisjoin using `block_puma_xwalk', 
    keep if _m == 3


    replace is_new = is_new*puma_sum
    replace is_not_new = is_not_new*puma_sum
    segregation_indices is_new is_not_new, by(full_puma)

    gen year = `yr'
    order year, after(full_puma)
    compress

    save `values_`yr'', replace
}


tempfile main

use `values_2023', clear
save `main'

foreach yr of numlist `processed_years' {
    use `values_`yr'', clear
    append using `main'
    save `main', replace
}
sort full_puma year


save "$geo_rhs_dir/segregation/segregation_new`fsuffix'", replace


* Seems to a last testing step where I look at serial correlation of
* the segregation measures. Only works as intended with two groups.
/*preserve
reshape wide d_index-hhi, i(full_puma) j(year)
corr d_index*
corr mi_index*
corr iso_group1*
corr iso_group2*
corr hhi*
restore*/




//    var 04: old <-- units built 50 years or more prior to census year
foreach yr of numlist `processed_years' {

    tempfile block_puma_xwalk values_`yr'

    run_puma_xwalk, yr(`yr') sourcedir($geo_xwalk_dir/BGtoPUMA)
    * Add subarea(2) or subarea(3) as we iterate through alternative geos
    run_consistent_pumas, sourcedir($geo_xwalk_dir) subarea(`geo_lvls')
    save `block_puma_xwalk'

    * TOM: The NHGIS tables can either be downloaded separately for each
    * variable of interest, or we can merge tables covering multiple variables
    * together.
    if `yr' == 1990 {
        import delimited `rhsdir'/nhgis0016_ds123_1990_blck_grp_598.csv, clear
        
        gen is_old = ex7008    /*    1940 and earlier    */
        egen is_not_old = rowtotal(ex7001-ex7007)
        
    }
    else if `yr' == 2000 {
        import delimited `rhsdir'/nhgis0016_ds152_2000_blck_grp_090.csv, clear
        
        egen is_old = rowtotal(g67008-g67009)    /*    1950 and earlier    */
        egen is_not_old = rowtotal(g67001-g67007)
        
    }
    /*else if `yr' == 2005 {
        import delimited `rhsdir'/nhgis0016_ds195_20095_blck_grp.csv, clear
        
        egen is_old = rowtotal(rq2e008-rq2e010)    /*    1960 and earlier    */
        egen is_not_old = rowtotal(rq2e002-rq2e007)
        
    }*/
    else if `yr' == 2010 {
        import delimited `rhsdir'/nhgis0016_ds176_20105_blck_grp.csv, clear
        
        egen is_old = rowtotal(jsde008-jsde010)    /*    1960 and earlier    */
        egen is_not_old = rowtotal(jsde002-jsde007)
        
    }
    else if `yr' == 2012 {
        import delimited `rhsdir'/nhgis0016_ds191_20125_blck_grp.csv, clear
        
        egen is_old = rowtotal(qy1e008-qy1e010)    /*    1960 and earlier    */
        egen is_not_old = rowtotal(qy1e002-qy1e007)
    }
    else if `yr' == 2014 {
        import delimited `rhsdir'/nhgis0016_ds206_20145_blck_grp.csv, clear
      
        egen is_old = rowtotal(abhpe008-abhpe010)    /*    1960 and earlier    */
        egen is_not_old = rowtotal(abhpe002-abhpe007)    
    }
    else if `yr' == 2017 {
        import delimited `rhsdir'/nhgis0016_ds233_20175_blck_grp.csv, clear
      
        egen is_old = rowtotal(ah4ze008-ah4ze011)    /*    1970 and earlier    */
        egen is_not_old = rowtotal(ah4ze002-ah4ze007)
    }
    else if `yr' == 2021 {
        import delimited `rhsdir'/nhgis0016_ds254_20215_blck_grp.csv, clear
      
        egen is_old = rowtotal(aothe008-aothe011)    /*    1970 and earlier    */
        egen is_not_old = rowtotal(aothe002-aothe007)    
    }
   else if `yr' == 2022 {
        import delimited `rhsdir'/nhgis0016_ds262_20225_blck_grp.csv, clear    
        
        egen is_old = rowtotal(aqt0e008-aqt0e011)    /*    1970 and earlier    */
        egen is_not_old = rowtotal(aqt0e002-aqt0e007)
    }
    else if `yr' == 2023 {
        import delimited `rhsdir'/nhgis0016_ds267_20235_blck_grp.csv, clear    
        
        egen is_old = rowtotal(asuje008-asuje011)    /*    1970 and earlier    */
        egen is_not_old = rowtotal(asuje002-asuje007)
    }


    merge 1:n gisjoin using `block_puma_xwalk', 
    keep if _m == 3


    replace is_old = is_old*puma_sum
    replace is_not_old = is_not_old*puma_sum
    segregation_indices is_old is_not_old, by(full_puma)

    gen year = `yr'
    order year, after(full_puma)
    compress

    save `values_`yr'', replace
}


tempfile main

* Now form a long panel with the iterated data
use `values_2023', clear
save `main'

foreach yr of numlist `processed_years' {
    use `values_`yr'', clear
    append using `main'
    save `main', replace
}
sort full_puma year


save "$geo_rhs_dir/segregation/segregation_old`fsuffix'", replace


* Seems to a last testing step where I look at serial correlation of
* the segregation measures. Only works as intended with two groups.
/*preserve
reshape wide d_index-hhi, i(full_puma) j(year)
corr d_index*
corr mi_index*
corr iso_group1*
corr iso_group2*
corr hhi*
restore*/



/*
//    var 05: small  <--  those with 3 or fewer rooms (1br)

//    according to the census bureau:
*    Include only whole rooms used for living purposes, such as living rooms, 
*    dining rooms, kitchens, bedrooms, finished recreation rooms, family rooms, 
*    enclosed porches suitable for year-round use, etc.
*    DO NOT count bathrooms, kitchenettes, strip or pullman kitchens, 
*    utility rooms, foyers, halls, open porches, balconies, unfinished attics, 
*    unfinished basements, or other unfinished space used for storage.
//    on this basis I'm assuing 3 rooms = 1 bedroom apartment

foreach yr of numlist 1990 2000 2010 2020 {

    tempfile block_puma_xwalk values_`yr'

    run_puma_xwalk, yr(`yr') sourcedir($geo_xwalk_dir/BGtoPUMA)
    * Add subarea(2) or subarea(3) as we iterate through alternative geos
    run_consistent_pumas, sourcedir($geo_xwalk_dir) subarea(`geo_lvls')
    save `block_puma_xwalk'

    * TOM: The NHGIS tables can either be downloaded separately for each
    * variable of interest, or we can merge tables covering multiple variables
    * together.
    if `yr' == 1990 {
        import delimited `rhsdir'/nhgis0003_ds123_1990_blck_grp_598.csv, clear
        
        egen is_small = rowtotal(exx001-exx003)
        egen is_not_small = rowtotal(exx004-exx009)
        
    }
    *    no data for 2000, so commenting it out for now
    /*else if `yr' == 2000 {
        import delimited `rhsdir'/nhgis0003_ds152_2000_blck_grp_090.csv, clear
        
        egen is_small = rowtotal(g67001-g67003)
        egen is_not_small = rowtotal(g67004-g67009)
        
    }*/
    else if `yr' == 2010 {
        import delimited `rhsdir'/nhgis0003_ds184_20115_blck_grp.csv, clear
        
        * An annoying thing with the ACSes is that even if the tables are
        * defined consistently, the variable names for same variables will change
        * over time. This hack will retrieve the variable name, but only if
        * the CSV is a pull of one and only one table.
        *    ds *e00*
        *    local acs_prefix = substr("`r(varlist)'", 1, 4)
        
        egen is_small = rowtotal(mtne002-mtne004)
        egen is_not_small = rowtotal(mtne005-mtne010)
    }
    else if `yr' == 2020 {
        import delimited `rhsdir'/nhgis0003_ds244_20195_blck_grp.csv, clear    
        
        *    ds *e00*
        *    local acs_prefix = substr("`r(varlist)'", 1, 4)
        
        egen is_small = rowtotal(alz4e002-alz4e004)
        egen is_not_small = rowtotal(alz4e005-alz4e010)
    }


    merge 1:n gisjoin using `block_puma_xwalk', 
    keep if _m == 3


    replace is_small = is_small*puma_sum
    replace is_not_small = is_not_small*puma_sum
    segregation_indices is_small is_not_small, by(full_puma)

    gen year = `yr'
    order year, after(full_puma)
    compress

    save `values_`yr'', replace
}


tempfile main

use `values_2020', clear
save `main'

foreach yr of numlist 2010 2000 1990 {
    use `values_`yr'', clear
    append using `main'
    save `main', replace
}
sort full_puma year


save "$geo_rhs_dir/segregation/segregation_small`fsuffix'", replace


* Seems to a last testing step where I look at serial correlation of
* the segregation measures. Only works as intended with two groups.
/*preserve
reshape wide d_index-hhi, i(full_puma) j(year)
corr d_index*
corr mi_index*
corr iso_group1*
corr iso_group2*
corr hhi*
restore*/
*/



//    var 06: vacant
foreach yr of numlist `processed_years' {

    tempfile block_puma_xwalk values_`yr'

    run_puma_xwalk, yr(`yr') sourcedir($geo_xwalk_dir/BGtoPUMA)
    * Add subarea(2) or subarea(3) as we iterate through alternative geos
    run_consistent_pumas, sourcedir($geo_xwalk_dir) subarea(`geo_lvls')
    save `block_puma_xwalk'

    * TOM: The NHGIS tables can either be downloaded separately for each
    * variable of interest, or we can merge tables covering multiple variables
    * together.
    if `yr' == 1990 {
        import delimited `rhsdir'/nhgis0004_ds123_1990_blck_grp_598.csv, clear
        
        gen is_vacant = eyp002
        gen is_not_vacant = eyp001
        
    }
    else if `yr' == 2000 {
        import delimited `rhsdir'/nhgis0004_ds152_2000_blck_grp_090.csv, clear
        
        gen is_vacant = g5z002
        gen is_not_vacant = g5z001
        
    }
    /*else if `yr' == 2005 {
        import delimited `rhsdir'/nhgis0016_ds195_20095_blck_grp.csv, clear
        
        gen is_vacant = rqje001
        gen is_not_vacant = rp9e001
        
    }*/
    else if `yr' == 2010 {
        import delimited `rhsdir'/nhgis0016_ds176_20105_blck_grp.csv, clear
        
        gen is_vacant = jrue001
        gen is_not_vacant = jrke001
    }
    else if `yr' == 2012 {
        import delimited `rhsdir'/nhgis0016_ds191_20125_blck_grp.csv, clear
        
        gen is_vacant = qyie001
        gen is_not_vacant = qx8e001
    }
    else if `yr' == 2014 {
        import delimited `rhsdir'/nhgis0016_ds206_20145_blck_grp.csv, clear
        
        gen is_vacant = abg7e001
        gen is_not_vacant = abgxe001
    }
    else if `yr' == 2017 {
        import delimited `rhsdir'/nhgis0016_ds233_20175_blck_grp.csv, clear
        
        gen is_vacant = ah4he001
        gen is_not_vacant = ah37e001
    }
    else if `yr' == 2021 {
        import delimited `rhsdir'/nhgis0016_ds254_20215_blck_grp.csv, clear
        
        gen is_vacant = aosze001
        gen is_not_vacant = aospe001
    }
    else if `yr' == 2022 {
        import delimited `rhsdir'/nhgis0016_ds262_20225_blck_grp.csv, clear
        
        gen is_vacant = aqs0e001
        gen is_not_vacant = aqsqe001
    }
    else if `yr' == 2023 {
        import delimited `rhsdir'/nhgis0016_ds267_20235_blck_grp.csv, clear    
        
        gen is_vacant = astje001
        gen is_not_vacant = ass9e001
    }


    merge 1:n gisjoin using `block_puma_xwalk', 
    keep if _m == 3


    replace is_vacant = is_vacant*puma_sum
    replace is_not_vacant = is_not_vacant*puma_sum
    segregation_indices is_vacant is_not_vacant, by(full_puma)

    gen year = `yr'
    order year, after(full_puma)
    compress

    save `values_`yr'', replace
}


tempfile main

use `values_2023', clear
save `main'

foreach yr of numlist `processed_years' {
    use `values_`yr'', clear
    append using `main'
    save `main', replace
}
sort full_puma year


save "$geo_rhs_dir/segregation/segregation_vacant`fsuffix'", replace


* Seems to a last testing step where I look at serial correlation of
* the segregation measures. Only works as intended with two groups.
/*preserve
reshape wide d_index-hhi, i(full_puma) j(year)
corr d_index*
corr mi_index*
corr iso_group1*
corr iso_group2*
corr hhi*
restore*/




//    var 07: multifamily        <-- here I'm assuing multifamily = 5 or more units
foreach yr of numlist `processed_years' {

    tempfile block_puma_xwalk values_`yr'

    run_puma_xwalk, yr(`yr') sourcedir($geo_xwalk_dir/BGtoPUMA)
    * Add subarea(2) or subarea(3) as we iterate through alternative geos
    run_consistent_pumas, sourcedir($geo_xwalk_dir) subarea(`geo_lvls')
    save `block_puma_xwalk'

    * TOM: The NHGIS tables can either be downloaded separately for each
    * variable of interest, or we can merge tables covering multiple variables
    * together.
    if `yr' == 1990 {
        import delimited `rhsdir'/nhgis0016_ds123_1990_blck_grp_598.csv, clear
        
        egen is_mf = rowtotal(ex2005-ex2008)
        egen is_not_mf = rowtotal(ex2001-ex2004)
        
    }
    else if `yr' == 2000 {
        import delimited `rhsdir'/nhgis0016_ds152_2000_blck_grp_090.csv, clear
        
        egen is_mf = rowtotal(g63005-g63008)
        egen is_not_mf = rowtotal(g63001-g63004)
        
    }
    /*else if `yr' == 2005 {
        import delimited `rhsdir'/nhgis0016_ds195_20095_blck_grp.csv, clear
        
        egen is_mf = rowtotal(rqze006-rqze009)
        egen is_not_mf = rowtotal(rqze002-rqze005)
        
    }*/
    else if `yr' == 2010 {
        import delimited `rhsdir'/nhgis0016_ds176_20105_blck_grp.csv, clear
        
        egen is_mf = rowtotal(jsae006-jsae009)
        egen is_not_mf = rowtotal(jsae002-jsae005)
        
    }
    else if `yr' == 2012 {
        import delimited `rhsdir'/nhgis0016_ds191_20125_blck_grp.csv, clear
        
        egen is_mf = rowtotal(qyye006-qyye009)
        egen is_not_mf = rowtotal(qyye002-qyye005)
    }
    else if `yr' == 2014 {
        import delimited `rhsdir'/nhgis0016_ds206_20145_blck_grp.csv, clear
        
        egen is_mf = rowtotal(abhme006-abhme009)
        egen is_not_mf = rowtotal(abhme002-abhme005)
    }
    else if `yr' == 2017 {
        import delimited `rhsdir'/nhgis0016_ds233_20175_blck_grp.csv, clear
        
        egen is_mf = rowtotal(ah4we006-ah4we009)
        egen is_not_mf = rowtotal(ah4we002-ah4we005)
    }
    else if `yr' == 2021 {
        import delimited `rhsdir'/nhgis0016_ds254_20215_blck_grp.csv, clear
        
        egen is_mf = rowtotal(aotem006-aotem009)
        egen is_not_mf = rowtotal(aotem002-aotem005)
    }
    else if `yr' == 2022 {
        import delimited `rhsdir'/nhgis0016_ds262_20225_blck_grp.csv, clear    
        
        egen is_mf = rowtotal(aqtxe006-aqtxe009)
        egen is_not_mf = rowtotal(aqtxe002-aqtxe005)
    }
    else if `yr' == 2023 {
        import delimited `rhsdir'/nhgis0016_ds267_20235_blck_grp.csv, clear    
        
        egen is_mf = rowtotal(asuge006-asuge009)
        egen is_not_mf = rowtotal(asuge002-asuge005)
    }


    merge 1:n gisjoin using `block_puma_xwalk', 
    keep if _m == 3


    replace is_mf = is_mf*puma_sum
    replace is_not_mf = is_not_mf*puma_sum
    segregation_indices is_mf is_not_mf, by(full_puma)

    gen year = `yr'
    order year, after(full_puma)
    compress

    save `values_`yr'', replace
}


tempfile main

use `values_2023', clear
save `main'

foreach yr of numlist `processed_years' {
    use `values_`yr'', clear
    append using `main'
    save `main', replace
}
sort full_puma year


save "$geo_rhs_dir/segregation/segregation_mf`fsuffix'", replace


* Seems to a last testing step where I look at serial correlation of
* the segregation measures. Only works as intended with two groups.
/*preserve
reshape wide d_index-hhi, i(full_puma) j(year)
corr d_index*
corr mi_index*
corr iso_group1*
corr iso_group2*
corr hhi*
restore*/

}


