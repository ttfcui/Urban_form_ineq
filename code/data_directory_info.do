
/*
        File name: data_directory_info.do
        Objective: Edit this file to ensure Stata scripts that follow
            load in data from the right directories.
        Last updated: 04/2026
*/


* Main directory for public data we've set up, which can vary by user.
* Once this is set, the subdirectories should follow a certain structure.

global project_dir ../../../urban_form_data        // For TC
*global project_dir          // For PG
*global project_dir          // For other RAs?

* Crosswalk directory for maintaining consistent PUMA panels across years
global geo_xwalk_dir $project_dir/Crosswalks

* This is the directory with all of PG's microdata pulled from IPUMS USA
global ipums_dir $project_dir/Pooya_data

* This captures block grp/tract level variation within PUMAs, mainly
* for constructing RHS variables
global geo_rhs_dir $project_dir/rhs_within_puma

* Separate directory for market stats, or PUMA-level average elasticities
global mkt_rhs_dir $project_dir/Market_stats

* Folder to store the long and wide versions of ineq index panel
global ineq_panel_dir $project_dir/Master_data

* Future directory for shares and stats taken out of Verisk unit-level data 
global geo_verisk_dir $project_dir/..  // TODO


* Temporary directory for intermediate merged data?
global analysis_temp_dir $project_dir/../temp
