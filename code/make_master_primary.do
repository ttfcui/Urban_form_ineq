

/* Processing of main inequality outcome data */

project, do(main_data/1_tc_puma_linkage.do)
project, do(main_data/2_TC_IPUMS_inc_calcs.do)
*project, do(main_data/3_IPUMS_inc_makemerged.do)


/* Auxiliary data */

project, do(auxiliary_data/build_market_stats.do)
project, do(main_data/4_PG_block2puma_aggregation.do)
project, do(main_data/4_1_PG_hhi_multigroup_aggregation.do)
