

//	this program merges segregation indices with inequality data	//
//	it then runs summary stats		//

*1	MERGE LONG DIFF VARS AND MAKE ONE FILE FOR EACH G1 G2 G3
*2	MERGE SEGREGATION STUFF WITH THE 3 FILES ABOVE

cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"

//	G1
foreach d in 7 9 14 19 {	//	<-- !!! run this loop just once
	use incineqG1_longitudinal_merged_laggedby`d'.dta
	renvars p90p50_p_hhLD - householdsLD, suffix(_`d')
	save, replace
	clear
}

use incineqG1_longitudinal_merged_laggedby7.dta
foreach d in 9 14 19 {
	merge 1:1 panel_id year using incineqG1_longitudinal_merged_laggedby`d'.dta, ///
	keepusing(p90p50_p_hhLD_`d' - householdsLD_`d') gen(_merge_LD`d')
}
	
save incineqG1, replace


//	G2
foreach d in 7 9 14 19 {	//	<-- !!! run this loop just once
	use incineqG2_longitudinal_merged_laggedby`d'.dta
	renvars p90p50_p_hhLD - householdsLD, suffix(_`d')
	save, replace
	clear
}

use incineqG2_longitudinal_merged_laggedby7.dta
foreach d in 9 14 19 {
	merge 1:1 panel_id year using incineqG2_longitudinal_merged_laggedby`d'.dta, ///
	keepusing(p90p50_p_hhLD_`d' - householdsLD_`d') gen(_merge_LD`d')
}
	
save incineqG2, replace


//	G3
foreach d in 7 9 14 19 {	//	<-- !!! run this loop just once
	use incineqG3_longitudinal_merged_laggedby`d'.dta
	renvars p90p50_p_hhLD - householdsLD, suffix(_`d')
	save, replace
	clear
}

use incineqG3_longitudinal_merged_laggedby7.dta
foreach d in 9 14 19 {
	merge 1:1 panel_id year using incineqG3_longitudinal_merged_laggedby`d'.dta, ///
	keepusing(p90p50_p_hhLD_`d' - householdsLD_`d') gen(_merge_LD`d')
}
	
save incineqG3, replace

	

//	merging various data
//	0	national gini, theil
//	1	segregation indices
//	2	market stats [distressed v booming, core v periphery]



//	0	national gini, theil



//	1	merge segregation indices
//	indices w/ 2 categories
foreach s in G1 G2 G3 {
	cd "D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation"

	use segregation_mf_`s'.dta
	renvars d_index-hhi, suffix(_mf)

	foreach i in new old owner sfr_detached vacant {
		merge 1:1 full_puma_matched year using segregation_`i'_`s'.dta, ///
		keepusing(d_index-hhi) generate(_merge_`i')
		
		drop if _merge_`i' == 2
		renvars d_index-hhi, suffix(_`i')
		drop _merge_`i'
	}
	
	replace year = 2008 if year == 2010
	replace year = 2010 if year == 2012
	replace year = 2012 if year == 2014
	replace year = 2015 if year == 2017
	replace year = 2019 if year == 2021
	replace year = 2021 if year == 2022
	replace year = 2022 if year == 2023
	
	save segregation_`s'.dta, replace

}
clear

//	hhi w/ multiple categories
foreach s in /*G1*/ G2 /*G3*/ {
	cd "D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation"
	
	use segregation_tenure_hhi_`s'.dta
	keep full_puma_matched year hhi
	rename hhi hhi_tenure
	
	foreach i in ht yrblt vacant {
		merge 1:1 full_puma_matched year using segregation_`i'_hhi_`s'.dta, ///
		keepusing(hhi) generate(_merge_`i')
		
		drop if _merge_`i' == 2
		rename hhi hhi_`i'
		drop _merge_`i'
	}
	
	replace year = 2008 if year == 2010
	replace year = 2010 if year == 2012
	replace year = 2012 if year == 2014
	replace year = 2015 if year == 2017
	replace year = 2019 if year == 2021
	replace year = 2021 if year == 2022
	replace year = 2022 if year == 2023
	
	save segregation_hhi_`s'.dta, replace

}
clear
	
	

foreach s in G1 G2 G3 {
	cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
	use incineq`s'.dta
	drop if missing(full_puma_matched)

	cd "D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation"
	merge 1:1 full_puma_matched year using segregation_`s'.dta, gen(_merge_seg_`s')
	merge 1:1 full_puma_matched year using segregation_hhi_`s'.dta, gen(_merge_seg_hhi_`s')
	drop if _merge_seg_`s' == 2
	drop if _merge_seg_hhi_`s' == 2
	tab _merge_seg_`s'
	tab _merge_seg_hhi_`s'
	tab year if _merge_seg_`s' == 3
	tab year if _merge_seg_hhi_`s' == 3

	cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
	save incineq_seg_`s'.dta, replace
	clear
}




//	2	merge market stats

foreach s in G1 G2 G3 {
	cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
	use incineq_seg_`s'.dta

	cd "D:\Inequality Urban Form\Tom Data\Core_Data\market_stats"
	merge m:1 full_puma_matched using PUMA_market_stats_`s'.dta, gen(_merge_mkstats_`s')
	drop if _merge_mkstats_`s' == 2
	cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
	save incineq_seg_mkstats_`s'.dta, replace
	clear
}


//	3	national gini, theil

foreach s in G1 G2 G3 {
	cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
	use incineq_seg_mkstats_`s'.dta
	merge m:1 year using incineq_ntl.dta, gen(_merge_ineq_ntl_`s')
	drop if _merge_ineq_ntl_`s' == 2
	save incineq_seg_mkstats_full_`s'.dta, replace
	clear
}




////	summary stats	////
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta

program define metro_rank

	gen metro_rank =	1	 if met2013 == 	35620
	replace metro_rank =	2	 if met2013 == 	31080
	replace metro_rank =	3	 if met2013 == 	16980
	replace metro_rank =	4	 if met2013 == 	19100
	replace metro_rank =	5	 if met2013 == 	26420
	replace metro_rank =	6	 if met2013 == 	47900
	replace metro_rank =	7	 if met2013 == 	37980
	replace metro_rank =	8	 if met2013 == 	12060
	replace metro_rank =	9	 if met2013 == 	33100
	replace metro_rank =	10	 if met2013 == 	38060
	replace metro_rank =	11	 if met2013 == 	14460
	replace metro_rank =	12	 if met2013 == 	40140
	replace metro_rank =	13	 if met2013 == 	41860
	replace metro_rank =	14	 if met2013 == 	19820
	replace metro_rank =	15	 if met2013 == 	42660
	replace metro_rank =	16	 if met2013 == 	33460
	replace metro_rank =	17	 if met2013 == 	45300
	replace metro_rank =	18	 if met2013 == 	41740
	replace metro_rank =	19	 if met2013 == 	19740
	replace metro_rank =	20	 if met2013 == 	41180
	replace metro_rank =	21	 if met2013 == 	16740
	replace metro_rank =	22	 if met2013 == 	12580
	replace metro_rank =	23	 if met2013 == 	36740
	replace metro_rank =	24	 if met2013 == 	41700
	replace metro_rank =	25	 if met2013 == 	12420
	replace metro_rank =	26	 if met2013 == 	38900
	replace metro_rank =	27	 if met2013 == 	40900
	replace metro_rank =	28	 if met2013 == 	29820
	replace metro_rank =	29	 if met2013 == 	38300
	replace metro_rank =	30	 if met2013 == 	28140
	replace metro_rank =	31	 if met2013 == 	17140
	replace metro_rank =	32	 if met2013 == 	26900
	replace metro_rank =	33	 if met2013 == 	34980
	replace metro_rank =	34	 if met2013 == 	18140
	replace metro_rank =	35	 if met2013 == 	17460
	replace metro_rank =	36	 if met2013 == 	41940
	replace metro_rank =	37	 if met2013 == 	47260
	replace metro_rank =	38	 if met2013 == 	39300
	replace metro_rank =	39	 if met2013 == 	27260
	replace metro_rank =	40	 if met2013 == 	33340
	replace metro_rank =	41	 if met2013 == 	39580
	replace metro_rank =	42	 if met2013 == 	36420
	replace metro_rank =	43	 if met2013 == 	40060
	replace metro_rank =	44	 if met2013 == 	41620
	replace metro_rank =	45	 if met2013 == 	31140
	replace metro_rank =	46	 if met2013 == 	35380
	replace metro_rank =	47	 if met2013 == 	32820
	replace metro_rank =	48	 if met2013 == 	15380
	replace metro_rank =	49	 if met2013 == 	13820
	replace metro_rank =	50	 if met2013 == 	25540
	replace metro_rank =	51	 if met2013 == 	40380
	replace metro_rank =	52	 if met2013 == 	46060
	replace metro_rank =	53	 if met2013 == 	36540
	replace metro_rank =	54	 if met2013 == 	24860
	replace metro_rank =	55	 if met2013 == 	23420
	replace metro_rank =	56	 if met2013 == 	46520
	replace metro_rank =	57	 if met2013 == 	49340
	replace metro_rank =	58	 if met2013 == 	24340
	replace metro_rank =	59	 if met2013 == 	14860
	replace metro_rank =	60	 if met2013 == 	10740
	replace metro_rank =	61	 if met2013 == 	12540
	replace metro_rank =	62	 if met2013 == 	28940
	replace metro_rank =	63	 if met2013 == 	35840
	replace metro_rank =	64	 if met2013 == 	32580
	replace metro_rank =	65	 if met2013 == 	10580
	replace metro_rank =	66	 if met2013 == 	10900
	replace metro_rank =	67	 if met2013 == 	21340
	replace metro_rank =	68	 if met2013 == 	12940
	replace metro_rank =	69	 if met2013 == 	35300
	replace metro_rank =	70	 if met2013 == 	14260
	replace metro_rank =	71	 if met2013 == 	37100
	replace metro_rank =	72	 if met2013 == 	16700
	replace metro_rank =	73	 if met2013 == 	15980
	replace metro_rank =	74	 if met2013 == 	19380
	replace metro_rank =	75	 if met2013 == 	44700
	replace metro_rank =	76	 if met2013 == 	29460
	replace metro_rank =	77	 if met2013 == 	17820
	replace metro_rank =	78	 if met2013 == 	30780
	replace metro_rank =	79	 if met2013 == 	19660
	replace metro_rank =	80	 if met2013 == 	39340
	replace metro_rank =	81	 if met2013 == 	10420
	replace metro_rank =	82	 if met2013 == 	49180
	replace metro_rank =	83	 if met2013 == 	45060
	replace metro_rank =	84	 if met2013 == 	44060
	replace metro_rank =	85	 if met2013 == 	37340
	replace metro_rank =	86	 if met2013 == 	48620
	replace metro_rank =	87	 if met2013 == 	25420
	replace metro_rank =	88	 if met2013 == 	44140
	replace metro_rank =	89	 if met2013 == 	38860
	replace metro_rank =	90	 if met2013 == 	22220
	replace metro_rank =	91	 if met2013 == 	29540
	replace metro_rank =	92	 if met2013 == 	16860
	replace metro_rank =	93	 if met2013 == 	33700
	replace metro_rank =	94	 if met2013 == 	12260
	replace metro_rank =	95	 if met2013 == 	49660
	replace metro_rank =	96	 if met2013 == 	45780
	replace metro_rank =	97	 if met2013 == 	37860
	replace metro_rank =	98	 if met2013 == 	42540
	replace metro_rank =	99	 if met2013 == 	41500
	replace metro_rank =	100	 if met2013 == 	39900

	//	summary stats for various segregation indices, broken down by
	//	top and bottom 10 cities and year

	gen metro_top10 = 0
	replace metro_top10 = 1 if metro_rank < 11

	gen metro_bot10 = 0
	replace metro_bot10 = 1 if metro_rank > 89

	gen metro_bot20 = 0
	replace metro_bot20 = 1 if metro_rank > 79

end


//	2.1. Income inequality has undesirable outcomes for cities, and has worsened over time	//
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
label var gini_persinc_ntl "Personal Income Gini, US"
label var gini_hhinc_ntl "Household Income Gini, US"
label var ge1_persinc_ntl "Personal Income Theil, US"
label var ge1_hhinc_ntl "Household Income Theil, US"

preserve
	duplicates drop year, force
	
	cd "D:\Inequality Urban Form\Results for APPAM"
	
	/*	gini and theil, persinc	*/
	twoway (connected gini_persinc_ntl year, msymbol(square)) ///
		   (connected ge1_persinc_ntl year, msymbol(circle)), ///
		   ytitle(Gini) xtitle(Year) title("National Inequality Over Time") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251013_ineq_ntl_persinc.gph, replace 
	graph export 20251013_ineq_ntl_persinc.png, as(png) replace
	
	/*	gini and theil, hhinc	*/
	twoway (connected gini_hhinc_ntl year, msymbol(square)) ///
		   (connected ge1_hhinc_ntl year, msymbol(circle)), ///
		   ytitle(Theil) xtitle(Year) title("National Inequality Over Time") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251013_ineq_ntl_hhinc.gph, replace 
	graph export 20251013_ineq_ntl_hhinc.png, as(png) replace
	
restore



//	2.2. Divergence: Trajectory of income inequality over time	//

//	2.2.1. Between large and small metros	//
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
foreach s in top10 bot10 bot20 {
	preserve
		keep if metro_`s' == 1
		
		duplicates drop year met2013, force

		bysort year: egen met_gini_`s' = mean(met_gini)
		bysort year: egen met_theil_`s' = mean(met_theil)
		
		save "D:\Inequality Urban Form\temp\ineq_`s'.dta", replace
	restore
}


clear

foreach s in top10 bot10 bot20 {
	use "D:\Inequality Urban Form\temp\ineq_`s'.dta"
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_slim_`s'.dta", replace
	clear
}
	//	assemble data for graphs
	use "D:\Inequality Urban Form\temp\ineq_slim_top10.dta"
	merge 1:1 year using "D:\Inequality Urban Form\temp\ineq_slim_bot10.dta", ///
		keepusing(met_gini_bot10 met_theil_bot10) gen(_merge_slim_bot10)
	merge 1:1 year using "D:\Inequality Urban Form\temp\ineq_slim_bot20.dta", ///
		keepusing(met_gini_bot20 met_theil_bot20) gen(_merge_slim_bot20)
		
	merge 1:1 year using "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged\incineq_ntl_full.dta", ///
		keepusing(gini_persinc_nonmet) gen(_merge_nonmet)
		
	cd "D:\Inequality Urban Form\Results for APPAM"

	label var met_gini_top10 "Gini in 10 largest metros"
	label var met_gini_bot10 "Gini in 10 smallest metros"
	label var met_theil_top10 "Theil in 10 largest metros"
	label var met_theil_bot10 "Theil in 10 smallest metros"
	label var gini_persinc_nonmet "Gini in non-metro areas"
	
	//	gini graph
	twoway (connected met_gini_top10 year, msymbol(square)) ///
		   (connected met_gini_bot10 year, msymbol(circle)) ///
		   /*(connected met_gini_bot20 year, msymbol(T))*/, ///
		   ytitle(Gini) yscale(range(.5 .55)) ylabel(.5(.01).55, grid) ///
		   xtitle(Year) ///
		   title("Gini in small and large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251013_gini_largesmall.gph, replace 
	graph export 20251013_gini_largesmall.png, as(png) replace

	//	theil graph
	twoway (connected met_theil_top10 year, msymbol(square)) ///
		   (connected met_theil_bot10 year, msymbol(circle)) ///
		   /*(connected met_theil_bot20 year, msymbol(T))*/, ///
		   ytitle(Theil) yscale(range(.44 .58)) ylabel(.44(.02).58, grid) ///
		   xtitle(Year) ///
		   title("Theil in small and large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251013_theil_largesmall.gph, replace 
	graph export 20251013_theil_largesmall.png, as(png) replace
	
	//	more complate gini graph
	twoway (connected met_gini_top10 year, msymbol(square)) ///
		   (connected met_gini_bot10 year, msymbol(circle)) ///
		   (connected gini_persinc_nonmet year, msymbol(T)), ///
		   ytitle(Gini) yscale(range(.5 .55)) ylabel(.5(.01).55, grid) ///
		   xtitle(Year) ///
		   title("Gini in small and large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251026_gini_largesmall.gph, replace 
	graph export 20251026_gini_largesmall.png, as(png) replace

	clear


	
	
//	2.2.2. Between distressed and booming metros
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/

preserve
	keep if SLLM_Distress_Ranking == 1
	bysort year: egen gini_booming = mean(met_gini)
	bysort year: egen theil_booming = mean(met_theil)
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_booming.dta", replace
restore
preserve
	keep if SLLM_Distress_Ranking != 1 & SLLM_Distress_Ranking != .
	bysort year: egen gini_distressed = mean(met_gini)
	bysort year: egen theil_distressed = mean(met_theil)
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_distressed.dta", replace
restore
clear

use "D:\Inequality Urban Form\temp\ineq_booming.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\ineq_distressed.dta", ///
	keepusing(gini_distressed theil_distressed) gen(_merge_dist)
	
label var gini_booming "Gini in booming metros"
label var theil_booming "Theil in booming metros"
label var gini_distressed "Gini in distressed metros"
label var theil_distressed "Theil in distressed metros"

cd "D:\Inequality Urban Form\Results for APPAM"
	//	gini graph
	twoway (connected gini_booming year, msymbol(square)) ///
		   (connected gini_distressed year, msymbol(circle)), ///
		   ytitle(Gini) /*yscale(range(.46 .55)) ylabel(.46(.01).55, grid)*/ ///
		   xtitle(Year) ///
		   title("Gini in booming and distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251013_gini_dist.gph, replace 
	graph export 20251013_gini_dist.png, as(png) replace

	//	theil graph
	twoway (connected theil_booming year, msymbol(square)) ///
		   (connected theil_distressed year, msymbol(circle)), ///
		   ytitle(Theil) /*yscale(range(.41 .58)) ylabel(.41(.02).58, grid)*/ ///
		   xtitle(Year) ///
		   title("Theil in booming and distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251013_theil_dist.gph, replace 
	graph export 20251013_theil_dist.png, as(png) replace

clear


//	2.2.3.	Between central and peripheral parts of metros
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/

//	core and peri in all 100 cities pooled

//	note:	percentiles of buildable_pct:
//			p25:	5.25%
//			p75:	54%

preserve
	keep if buildable_pct < 5.25
	bysort year: egen gini_core = mean(puma_gini)
	bysort year: egen theil_core = mean(puma_theil)
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_core.dta", replace
restore
preserve
	keep if buildable_pct > 54
	bysort year: egen gini_peri = mean(puma_gini)
	bysort year: egen theil_peri = mean(puma_theil)
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_peri.dta", replace
restore
clear

use "D:\Inequality Urban Form\temp\ineq_core.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\ineq_peri.dta", ///
	keepusing(gini_peri theil_peri) gen(_merge_peri)
	
label var gini_core "Gini in built up PUMAs"
label var theil_core "Theil in built up PUMAs"
label var gini_peri "Gini in lower density PUMAs"
label var theil_peri "Theil in lower density PUMAs"

cd "D:\Inequality Urban Form\Results for APPAM"
	//	gini graph
	twoway (connected gini_core year, msymbol(square)) ///
		   (connected gini_peri year, msymbol(circle)), ///
		   ytitle(Gini) yscale(range(.46 .53)) ylabel(.46(.01).53, grid) ///
		   xtitle(Year) ///
		   title("Gini in built up and lower density PUMAs") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251017_gini_core.gph, replace 
	graph export 20251017_gini_core.png, as(png) replace

	//	theil graph
	twoway (connected theil_core year, msymbol(square)) ///
		   (connected theil_peri year, msymbol(circle)), ///
		   ytitle(Theil) yscale(range(.41 .53)) ylabel(.41(.02).53, grid) ///
		   xtitle(Year) ///
		   title("Theil in built up and lower density PUMAs") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251017_theil_core.gph, replace 
	graph export 20251017_theil_core.png, as(png) replace

clear


//	core and peri in 10 largest metros	
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/

//			percentile of buildable_pct for top 10 metros:
//			p25:	1.669916%
//			p75:	34.45881%
keep if metro_top10 == 1
preserve
	keep if buildable_pct < 1.669916
	bysort year: egen gini_top10_core = mean(puma_gini)
	bysort year: egen theil_top10_core = mean(puma_theil)
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_top10_core.dta", replace
restore
preserve
	keep if buildable_pct > 34.45881
	bysort year: egen gini_top10_peri = mean(puma_gini)
	bysort year: egen theil_top10_peri = mean(puma_theil)
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_top10_peri.dta", replace
restore
clear

use "D:\Inequality Urban Form\temp\ineq_top10_core.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\ineq_top10_peri.dta", ///
	keepusing(gini_top10_peri theil_top10_peri) gen(_merge_top10_peri)
	
label var gini_top10_core "Gini in built up PUMAs (10 largest metros)"
label var theil_top10_core "Theil in built up PUMAs (10 largest metros)"
label var gini_top10_peri "Gini in lower density PUMAs (10 largest metros)"
label var theil_top10_peri "Theil in lower density PUMAs (10 largest metros)"

cd "D:\Inequality Urban Form\Results for APPAM"
	//	gini graph
	twoway (connected gini_top10_core year, msymbol(square)) ///
		   (connected gini_top10_peri year, msymbol(circle)), ///
		   ytitle(Gini) yscale(range(.46 .53)) ylabel(.46(.01).53, grid) ///
		   xtitle(Year) ///
		   title("Gini in built up and lower density PUMAs (10 largest metros)", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251017_gini_top10_core.gph, replace 
	graph export 20251017_gini_top10_core.png, as(png) replace

	//	theil graph
	twoway (connected theil_top10_core year, msymbol(square)) ///
		   (connected theil_top10_peri year, msymbol(circle)), ///
		   ytitle(Theil) yscale(range(.39 .53)) ylabel(.39(.02).53, grid) ///
		   xtitle(Year) ///
		   title("Theil in built up and lower density PUMAs (10 largest metros)", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251017_theil_top10_core.gph, replace 
	graph export 20251017_theil_top10_core.png, as(png) replace

clear



//	core and peri in 20 smallest metros	
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/

//			percentile of buildable_pct for bottom 20 metros:
//			p25:	25.38825%
//			p75:	66.54179%
keep if metro_bot20 == 1
preserve
	keep if buildable_pct < 25.38825
	bysort year: egen gini_bot20_core = mean(puma_gini)
	bysort year: egen theil_bot20_core = mean(puma_theil)
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_bot20_core.dta", replace
restore
preserve
	keep if buildable_pct > 66.54179
	bysort year: egen gini_bot20_peri = mean(puma_gini)
	bysort year: egen theil_bot20_peri = mean(puma_theil)
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\ineq_bot20_peri.dta", replace
restore
clear

use "D:\Inequality Urban Form\temp\ineq_bot20_core.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\ineq_bot20_peri.dta", ///
	keepusing(gini_bot20_peri theil_bot20_peri) gen(_merge_bot20_peri)
	
label var gini_bot20_core "Gini in built up PUMAs (20 smallest metros)"
label var theil_bot20_core "Theil in built up PUMAs (20 smallest metros)"
label var gini_bot20_peri "Gini in lower density PUMAs (20 smallest metros)"
label var theil_bot20_peri "Theil in lower density PUMAs (20 smallest metros)"

cd "D:\Inequality Urban Form\Results for APPAM"
	//	gini graph
	twoway (connected gini_bot20_core year, msymbol(square)) ///
		   (connected gini_bot20_peri year, msymbol(circle)), ///
		   ytitle(Gini) yscale(range(.47 .53)) ylabel(.47(.01).53, grid) ///
		   xtitle(Year) ///
		   title("Gini in built up and lower density PUMAs (20 smallest metros)", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251017_gini_bot20_core.gph, replace 
	graph export 20251017_gini_bot20_core.png, as(png) replace

	//	theil graph
	twoway (connected theil_bot20_core year, msymbol(square)) ///
		   (connected theil_bot20_peri year, msymbol(circle)), ///
		   ytitle(Theil) yscale(range(.39 .53)) ylabel(.39(.02).53, grid) ///
		   xtitle(Year) ///
		   title("Theil in built up and lower density PUMAs (20 smallest metros)", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251017_theil_bot20_core.gph, replace 
	graph export 20251017_theil_bot20_core.png, as(png) replace

clear




/*	2.3. Most income inequality in metropolitan areas 
		is attributable to variation among sub-metro areas	*/
		
//	Theil for all 100 cities pooled
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
mkdir "D:\Inequality Urban Form\Results for APPAM\decomp"
preserve
	bysort year: egen theil_all = mean(met_theil)
	bysort year: egen theil_all_win = mean(met_theil_within)
	bysort year: egen theil_all_bwn = mean(met_theil_btwn)
	duplicates drop year, force
	label var theil_all "Theil Index overall"
	label var theil_all_win "Theil Index w/in metro"
	label var theil_all_bwn "Theil Index b/w metros"
	
	cd "D:\Inequality Urban Form\Results for APPAM"
	twoway (connected theil_all year, msymbol(square)) ///
		   (connected theil_all_win year, msymbol(circle)), ///
		   ytitle(Theil) yscale(range(.41 .55)) ylabel(.41(.02).55, grid) ///
		   xtitle(Year) ///
		   title("Theil Index Decomposed, 100 Metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	graph save 20251019_theil_decomp_all.gph, replace 
	graph export 20251019_theil_decomp_all.png, as(png) replace
	
	save "D:\Inequality Urban Form\temp\ineq_decomp_all.dta", replace
restore
clear



//	Theil decomposed over time for top 10 metros
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
label var met_theil "Metro-wide Theil"
label var met_theil_within "Within-Metro Theil"
duplicates drop met2013 year, force
metro_rank
keep if metro_top10 == 1
levelsof met2013, local(metros)
cd "D:\Inequality Urban Form\Results for APPAM\decomp"
foreach m of local metros {
	local lbl : label (met2013) `m'
	twoway	(connected met_theil year if met2013 == `m', msymbol(square)) ///
			(connected met_theil_within year if met2013 == `m', msymbol(circle)), ///
	   ytitle(Theil) yscale(range(.38 .60)) ylabel(.38(.02).60, grid) ///
	   xtitle(Year) ///
	   title("Theil Index Decomposed") ///
	   subtitle("`lbl'", size(medium)) ///
	   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	   graph save 20251019_decomp_top10_`m'.gph, replace
	   graph export 20251019_decomp_top10_`m'.png, as(png) replace
}
clear


//	Theil decomposed over time for bottom 20 metros
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
label var met_theil "Metro-wide Theil"
label var met_theil_within "Within-Metro Theil"
duplicates drop met2013 year, force
metro_rank
keep if metro_bot20 == 1
levelsof met2013, local(metros)
cd "D:\Inequality Urban Form\Results for APPAM\decomp"
foreach m of local metros {
	local lbl : label (met2013) `m'
	twoway	(connected met_theil year if met2013 == `m', msymbol(square)) ///
			(connected met_theil_within year if met2013 == `m', msymbol(circle)), ///
	   ytitle(Theil) yscale(range(.38 .60)) ylabel(.38(.02).60, grid) ///
	   xtitle(Year) ///
	   title("Theil Index Decomposed") ///
	   subtitle("`lbl'", size(medium)) ///
	   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, grid angle (vertical))
	   graph save 20251019_decomp_bot20_`m'.gph, replace
	   graph export 20251019_decomp_bot20_`m'.png, as(png) replace
}

				


//	2.4.1.	Housing typology
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/

merge m:1 full_puma year using ///
	"D:\Inequality Urban Form\ACS\Hsg Vars PUMA\ACS_1yr_Hsg_PUMA_2005_thru_2022.dta", ///
	keepusing(dp04_0001e-dp04_0143pe) gen(_merge_hsg)

drop if _merge_hsg == 2
tab year _merge_hsg

//	(a) small v large metros
//	(b) distressed v booming metros
//	(c) central v peripheral PUMAs

label var dp04_0001e "total units"
label var dp04_0003pe "vacancy rate"
label var dp04_0007pe "share single family"
egen vartemp = rowtotal(dp04_0011e dp04_0012e dp04_0013e)
gen multifam_sh = vartemp / dp04_0006e
drop vartemp
label var multifam_sh "share multifamily"
label var dp04_0026pe "share built before 1940"
egen vartemp = rowtotal(dp04_0019e dp04_0018e dp04_0017e)
gen post2000 = vartemp / dp04_0016e
drop vartemp
label var post2000 "share built after 2000"
label var dp04_0037e "median rooms"
label var dp04_0046pe "share owner"

metro_rank
cd "D:\Inequality Urban Form\temp"

//	(a) small v large metros
preserve
	keep if metro_top10 == 1
	foreach var in	dp04_0001e dp04_0003pe dp04_0007pe multifam_sh dp04_0026pe ///
					post2000 dp04_0037e dp04_0046pe {
		estpost tabstat `var', statistics(count mean p50 sd min max sum) by(year)
		esttab using "metro_top10_`var'.csv", cells("count mean p50 sd min max sum") replace
	}
restore
preserve
	keep if metro_bot20 == 1
	foreach var in	dp04_0001e dp04_0003pe dp04_0007pe multifam_sh dp04_0026pe ///
					post2000 dp04_0037e dp04_0046pe {
		estpost tabstat `var', statistics(count mean p50 sd min max sum) by(year)
		esttab using "metro_bot20_`var'.csv", cells("count mean p50 sd min max sum") replace
	}
restore

//	(b) distressed v booming metros
preserve
	keep if SLLM_Distress_Ranking == 1
	foreach var in	dp04_0001e dp04_0003pe dp04_0007pe multifam_sh dp04_0026pe ///
					post2000 dp04_0037e dp04_0046pe {
		estpost tabstat `var', statistics(count mean p50 sd min max sum) by(year)
		esttab using "boom_`var'.csv", cells("count mean p50 sd min max sum") replace
	}
restore
preserve
	keep if SLLM_Distress_Ranking != 1 & SLLM_Distress_Ranking != .
	foreach var in	dp04_0001e dp04_0003pe dp04_0007pe multifam_sh dp04_0026pe ///
					post2000 dp04_0037e dp04_0046pe {
		estpost tabstat `var', statistics(count mean p50 sd min max sum) by(year)
		esttab using "dist_`var'.csv", cells("count mean p50 sd min max sum") replace
	}
restore

//	(c) central v peripheral PUMAs
preserve
	keep if buildable_pct < 5.25
	foreach var in	dp04_0001e dp04_0003pe dp04_0007pe multifam_sh dp04_0026pe ///
					post2000 dp04_0037e dp04_0046pe {
		estpost tabstat `var', statistics(count mean p50 sd min max sum) by(year)
		esttab using "core_`var'.csv", cells("count mean p50 sd min max sum") replace
	}
restore
preserve
	keep if buildable_pct > 54
	foreach var in	dp04_0001e dp04_0003pe dp04_0007pe multifam_sh dp04_0026pe ///
					post2000 dp04_0037e dp04_0046pe {
		estpost tabstat `var', statistics(count mean p50 sd min max) by(year)
		esttab using "peri_`var'.csv", cells("count mean p50 sd min max sum") replace
	}
restore

clear


//	2.4.2.	Housing segregation
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
metro_rank
renvars *_sfr_detached, subst(_sfr_detached _sf)

//	large and small metros
preserve
	keep if metro_top10 == 1
	foreach var in mf new old owner sf vacant {
		bysort year: egen d_index_avg_top10_`var' = mean(d_index_`var')
		bysort year: egen iso_group1_avg_top10_`var' = mean(iso_group1_`var')
	}
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\seg_top10.dta", replace
restore
preserve
	keep if metro_bot20 == 1
	foreach var in mf new old owner sf vacant {
		bysort year: egen d_index_avg_bot20_`var' = mean(d_index_`var')
		bysort year: egen iso_group1_avg_bot20_`var' = mean(iso_group1_`var')
	}
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\seg_bot20.dta", replace
restore
clear

use "D:\Inequality Urban Form\temp\seg_top10.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\seg_bot20.dta", ///
	keepusing(d_index_avg_bot20_mf-iso_group1_avg_bot20_vacant) gen(_merge_seg)
	
label var d_index_avg_top10_mf "Dissimilarity, Multifamily, 10 Largest Metros"
label var iso_group1_avg_top10_mf "Isolation, Multifamily, 10 Largest Metros"
label var d_index_avg_top10_new "Dissimilarity, Newer Homes, 10 Largest Metros"
label var iso_group1_avg_top10_new "Isolation, Newer Homes, 10 Largest Metros"
label var d_index_avg_top10_old "Dissimilarity, Older Homes, 10 Largest Metros"
label var iso_group1_avg_top10_old "Isolation, Older Homes, 10 Largest Metros"
label var d_index_avg_top10_owner "Dissimilarity, Owner Occ, 10 Largest Metros"
label var iso_group1_avg_top10_owner "Isolation, Owner Occ, 10 Largest Metros"
label var d_index_avg_top10_sf "Dissimilarity, Single Fam, 10 Largest Metros"
label var iso_group1_avg_top10_sf "Isolation, Single Fam, 10 Largest Metros"
label var d_index_avg_top10_vacant "Dissimilarity, Vacant Units, 10 Largest Metros"
label var iso_group1_avg_top10_vacant "Isolation, Vacant Units, 10 Largest Metros"
label var d_index_avg_bot20_mf "Dissimilarity, Multifamily, 20 Smallest Metros"
label var iso_group1_avg_bot20_mf "Isolation, Multifamily, 20 Smallest Metros"
label var d_index_avg_bot20_new "Dissimilarity, Newer Homes, 20 Smallest Metros"
label var iso_group1_avg_bot20_new "Isolation, Newer Homes, 20 Smallest Metros"
label var d_index_avg_bot20_old "Dissimilarity, Older Homes, 20 Smallest Metros"
label var iso_group1_avg_bot20_old "Isolation, Older Homes, 20 Smallest Metros"
label var d_index_avg_bot20_owner "Dissimilarity, Owner Occ, 20 Smallest Metros"
label var iso_group1_avg_bot20_owner "Isolation, Owner Occ, 20 Smallest Metros"
label var d_index_avg_bot20_sf "Dissimilarity, Single Fam, 20 Smallest Metros"
label var iso_group1_avg_bot20_sf "Isolation, Single Fam, 20 Smallest Metros"
label var d_index_avg_bot20_vacant "Dissimilarity, Vacant Units, 20 Smallestt Metros"
label var iso_group1_avg_bot20_vacant "Isolation, Vacant Units, 20 Smallest Metros"

replace d_index_avg_top10_mf = . in 8
replace d_index_avg_bot20_mf = . in 8
replace iso_group1_avg_top10_sf = . in 7
replace d_index_avg_top10_sf = . in 7
replace d_index_avg_bot20_sf = . in 7
replace iso_group1_avg_bot20_sf = . in 7
replace d_index_avg_bot20_owner = .41508164 in 1
replace d_index_avg_top10_old = .44069463 in 1
replace iso_group1_avg_top10_new = . in 7
replace iso_group1_avg_bot20_new = . in 7



cd "D:\Inequality Urban Form\Results for APPAM"

	foreach s in top10 bot20 {
//	dissimilarity graphs
	//	owner v renter
	twoway (connected d_index_avg_`s'_owner year, msymbol(square)) ///
		   /*(connected d_index_avg_`s'_mf year, msymbol(circle))*/, ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_owner_`s'.gph, replace 
	graph export 20251026_dissim_owner_`s'.png, as(png) replace
	//	sf v mf
	twoway (connected d_index_avg_`s'_sf year, msymbol(square)) ///
		   (connected d_index_avg_`s'_mf year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_sfmf_`s'.gph, replace 
	graph export 20251026_dissim_sfmf_`s'.png, as(png) replace
	//	old v new
	twoway (connected d_index_avg_`s'_old year, msymbol(square)) ///
		   (connected d_index_avg_`s'_new year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_oldnew_`s'.gph, replace 
	graph export 20251026_dissim_oldnew_`s'.png, as(png) replace
	//	vacant
	twoway (connected d_index_avg_`s'_vacant year, msymbol(square)) ///
		   /*(connected d_index_avg_top10_mf year, msymbol(circle))*/, ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_vacant_`s'.gph, replace 
	graph export 20251026_dissim_vacant_`s'.png, as(png) replace
	
	
//	isolation graphs
	//	owner v renter
	twoway (connected iso_group1_avg_`s'_owner year, msymbol(square)) ///
		   /*(connected iso_group1_avg_`s'_mf year, msymbol(circle))*/, ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_owner_`s'.gph, replace 
	graph export 20251026_iso_owner_`s'.png, as(png) replace
	//	sf v mf
	twoway (connected iso_group1_avg_`s'_sf year, msymbol(square)) ///
		   (connected iso_group1_avg_`s'_mf year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_sfmf_`s'.gph, replace 
	graph export 20251026_iso_sfmf_`s'.png, as(png) replace
	//	old v new
	twoway (connected iso_group1_avg_`s'_old year, msymbol(square)) ///
		   (connected iso_group1_avg_`s'_new year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_oldnew_`s'.gph, replace 
	graph export 20251026_iso_oldnew_`s'.png, as(png) replace
	//	vacant
	twoway (connected iso_group1_avg_`s'_vacant year, msymbol(square)) ///
		   /*(connected iso_group1_avg_`s'_mf year, msymbol(circle))*/, ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_vacant_`s'.gph, replace 
	graph export 20251026_iso_vacant_`s'.png, as(png) replace
}	
	

/*	
//	older version that compared large and small metros
foreach var in mf new old owner sf vacant {
	//	dissimilarity graph
	twoway (connected d_index_avg_top10_`var' year, msymbol(square)) ///
		   (connected d_index_avg_bot20_`var' year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251023_dissim_`var'_small_large.gph, replace 
	graph export 20251023_dissim_`var'_small_large.png, as(png) replace

	//	isolation graph
	twoway (connected iso_group1_avg_top10_`var' year, msymbol(square)) ///
		   (connected iso_group1_avg_bot20_`var' year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251023_iso_`var'_small_large.gph, replace 
	graph export 20251023_iso_`var'_small_large.png, as(png) replace
}
clear
*/

//	distressed and booming PUMAs
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
metro_rank
renvars *_sfr_detached, subst(_sfr_detached _sf)

preserve
	keep if SLLM_Distress_Ranking == 1
	foreach var in mf new old owner sf vacant {
		bysort year: egen d_index_avg_boom_`var' = mean(d_index_`var')
		bysort year: egen iso_group1_avg_boom_`var' = mean(iso_group1_`var')
	}
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\seg_boom.dta", replace
restore
preserve
	keep if SLLM_Distress_Ranking != 1 & SLLM_Distress_Ranking != .
	foreach var in mf new old owner sf vacant {
		bysort year: egen d_index_avg_dist_`var' = mean(d_index_`var')
		bysort year: egen iso_group1_avg_dist_`var' = mean(iso_group1_`var')
	}
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\seg_dist.dta", replace
restore
clear

use "D:\Inequality Urban Form\temp\seg_boom.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\seg_dist.dta", ///
	keepusing(d_index_avg_dist_mf-iso_group1_avg_dist_vacant) gen(_merge_seg)
	
label var d_index_avg_boom_mf "Dissimilarity, Multifamily, Booming Metros"
label var iso_group1_avg_boom_mf "Isolation, Multifamily, Booming Metros"
label var d_index_avg_boom_new "Dissimilarity, Newer Homes, Booming Metros"
label var iso_group1_avg_boom_new "Isolation, Newer Homes, Booming Metros"
label var d_index_avg_boom_old "Dissimilarity, Older Homes, Booming Metros"
label var iso_group1_avg_boom_old "Isolation, Older Homes, Booming Metros"
label var d_index_avg_boom_owner "Dissimilarity, Owner Occ, Booming Metros"
label var iso_group1_avg_boom_owner "Isolation, Owner Occ, Booming Metros"
label var d_index_avg_boom_sf "Dissimilarity, Single Fam, Booming Metros"
label var iso_group1_avg_boom_sf "Isolation, Single Fam, Booming Metros"
label var d_index_avg_boom_vacant "Dissimilarity, Vacant Units, Booming Metros"
label var iso_group1_avg_boom_vacant "Isolation, Vacant Units, Booming Metros"
label var d_index_avg_dist_mf "Dissimilarity, Multifamily, Distressed Metros"
label var iso_group1_avg_dist_mf "Isolation, Multifamily, Distressed Metros"
label var d_index_avg_dist_new "Dissimilarity, Newer Homes, Distressed Metros"
label var iso_group1_avg_dist_new "Isolation, Newer Homes, Distressed Metros"
label var d_index_avg_dist_old "Dissimilarity, Older Homes, Distressed Metros"
label var iso_group1_avg_dist_old "Isolation, Older Homes, Distressed Metros"
label var d_index_avg_dist_owner "Dissimilarity, Owner Occ, Distressed Metros"
label var iso_group1_avg_dist_owner "Isolation, Owner Occ, Distressed Metros"
label var d_index_avg_dist_sf "Dissimilarity, Single Fam, Distressed Metros"
label var iso_group1_avg_dist_sf "Isolation, Single Fam, Distressed Metros"
label var d_index_avg_dist_vacant "Dissimilarity, Vacant Units, Distressed Metros"
label var iso_group1_avg_dist_vacant "Isolation, Vacant Units, Distressed Metros"

replace d_index_avg_boom_mf = . in 8
replace d_index_avg_boom_sf = . in 7
replace iso_group1_avg_boom_sf = . in 7
replace d_index_avg_dist_sf = . in 7
replace iso_group1_avg_dist_sf = . in 7
replace iso_group1_avg_boom_old = . in 6
replace iso_group1_avg_dist_old = . in 6
replace iso_group1_avg_boom_new = . in 7
replace iso_group1_avg_dist_new = . in 7
replace d_index_avg_dist_mf = . in 8

cd "D:\Inequality Urban Form\Results for APPAM"

foreach t in boom dist {

//	dissimilarity graphs
	//	owner v renter
	twoway (connected d_index_avg_`t'_owner year, msymbol(square)) ///
		   /*(connected d_index_avg_`t'_mf year, msymbol(circle))*/, ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_owner_`t'.gph, replace 
	graph export 20251026_dissim_owner_`t'.png, as(png) replace
	//	sf v mf
	twoway (connected d_index_avg_`t'_sf year, msymbol(square)) ///
		   (connected d_index_avg_`t'_mf year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_sfmf_`t'.gph, replace 
	graph export 20251026_dissim_sfmf_`t'.png, as(png) replace
	//	old v new
	twoway (connected d_index_avg_`t'_old year, msymbol(square)) ///
		   (connected d_index_avg_`t'_new year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_oldnew_`t'.gph, replace 
	graph export 20251026_dissim_oldnew_`t'.png, as(png) replace
	//	vacant
	twoway (connected d_index_avg_`t'_vacant year, msymbol(square)) ///
		   /*(connected d_index_avg_`t'_mf year, msymbol(circle))*/, ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_vacant_`t'.gph, replace 
	graph export 20251026_dissim_vacant_`t'.png, as(png) replace

	
//	isolation graphs
	//	owner v renter
	twoway (connected iso_group1_avg_`t'_owner year, msymbol(square)) ///
		   /*(connected iso_group1_avg_`t'_mf year, msymbol(circle))*/, ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_owner_`t'.gph, replace 
	graph export 20251026_iso_owner_`t'.png, as(png) replace
	//	sf v mf
	twoway (connected iso_group1_avg_`t'_sf year, msymbol(square)) ///
		   (connected iso_group1_avg_`t'_mf year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_sfmf_`t'.gph, replace 
	graph export 20251026_iso_sfmf_`t'.png, as(png) replace
	//	old v new
	twoway (connected iso_group1_avg_`t'_old year, msymbol(square)) ///
		   (connected iso_group1_avg_`t'_new year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_oldnew_`t'.gph, replace 
	graph export 20251026_iso_oldnew_`t'.png, as(png) replace
	//	vacant
	twoway (connected iso_group1_avg_`t'_vacant year, msymbol(square)) ///
		   /*(connected iso_group1_avg_`t'_mf year, msymbol(circle))*/, ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_vacant_`t'.gph, replace 
	graph export 20251026_iso_vacant_`t'.png, as(png) replace
}

/*
//	older version that compared boom and dist
foreach var in mf new old owner sf vacant {
	//	dissimilarity graph
	twoway (connected d_index_avg_boom_`var' year, msymbol(square)) ///
		   (connected d_index_avg_dist_`var' year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251023_dissim_`var'_boomdist.gph, replace 
	graph export 20251023_dissim_`var'_boomdist.png, as(png) replace

	//	isolation graph
	twoway (connected iso_group1_avg_boom_`var' year, msymbol(square)) ///
		   (connected iso_group1_avg_dist_`var' year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251023_iso_`var'_boomdist.gph, replace 
	graph export 20251023_iso_`var'_boomdist.png, as(png) replace
}
clear
*/



//	core and peripheral PUMAs
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
metro_rank
renvars *_sfr_detached, subst(_sfr_detached _sf)

preserve
	keep if buildable_pct < 5.25
	foreach var in mf new old owner sf vacant {
		bysort year: egen d_index_avg_core_`var' = mean(d_index_`var')
		bysort year: egen iso_group1_avg_core_`var' = mean(iso_group1_`var')
	}
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\seg_core.dta", replace
restore
preserve
	keep if buildable_pct > 54
	foreach var in mf new old owner sf vacant {
		bysort year: egen d_index_avg_peri_`var' = mean(d_index_`var')
		bysort year: egen iso_group1_avg_peri_`var' = mean(iso_group1_`var')
	}
	duplicates drop year, force
	save "D:\Inequality Urban Form\temp\seg_peri.dta", replace
restore
clear

use "D:\Inequality Urban Form\temp\seg_core.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\seg_peri.dta", ///
	keepusing(d_index_avg_peri_mf-iso_group1_avg_peri_vacant) gen(_merge_seg)
	
label var d_index_avg_core_mf "Dissimilarity, Multifamily, Built Up PUMAs"
label var iso_group1_avg_core_mf "Isolation, Multifamily, Built Up PUMAs"
label var d_index_avg_core_new "Dissimilarity, Newer Homes, Built Up PUMAs"
label var iso_group1_avg_core_new "Isolation, Newer Homes, Built Up PUMAs"
label var d_index_avg_core_old "Dissimilarity, Older Homes, Built Up PUMAs"
label var iso_group1_avg_core_old "Isolation, Older Homes, Built Up PUMAs"
label var d_index_avg_core_owner "Dissimilarity, Owner Occ, Built Up PUMAs"
label var iso_group1_avg_core_owner "Isolation, Owner Occ, Built Up PUMAs"
label var d_index_avg_core_sf "Dissimilarity, Single Fam, Built Up PUMAs"
label var iso_group1_avg_core_sf "Isolation, Single Fam, Built Up PUMAs"
label var d_index_avg_core_vacant "Dissimilarity, Vacant Units, Built Up PUMAs"
label var iso_group1_avg_core_vacant "Isolation, Vacant Units, Built Up PUMAs"
label var d_index_avg_peri_mf "Dissimilarity, Multifamily, Lower Density PUMAs"
label var iso_group1_avg_peri_mf "Isolation, Multifamily, Lower Density PUMAs"
label var d_index_avg_peri_new "Dissimilarity, Newer Homes, Lower Density PUMAs"
label var iso_group1_avg_peri_new "Isolation, Newer Homes, Lower Density PUMAs"
label var d_index_avg_peri_old "Dissimilarity, Older Homes, Lower Density PUMAs"
label var iso_group1_avg_peri_old "Isolation, Older Homes, Lower Density PUMAs"
label var d_index_avg_peri_owner "Dissimilarity, Owner Occ, Lower Density PUMAs"
label var iso_group1_avg_peri_owner "Isolation, Owner Occ, Lower Density PUMAs"
label var d_index_avg_peri_sf "Dissimilarity, Single Fam, Lower Density PUMAs"
label var iso_group1_avg_peri_sf "Isolation, Single Fam, Lower Density PUMAs"
label var d_index_avg_peri_vacant "Dissimilarity, Vacant Units, Lower Density PUMAs"
label var iso_group1_avg_peri_vacant "Isolation, Vacant Units, Lower Density PUMAs"

replace iso_group1_avg_core_sf = . in 7
replace d_index_avg_core_sf = . in 7
replace d_index_avg_peri_sf = . in 7
replace iso_group1_avg_peri_sf = . in 7
replace d_index_avg_peri_owner = .42163109 in 6
replace d_index_avg_peri_owner = .4293156 in 7
replace d_index_avg_core_old = . in 2
replace iso_group1_avg_peri_new = . in 7
replace iso_group1_avg_core_mf = . in 8
replace d_index_avg_peri_mf = . in 8
replace d_index_avg_core_mf = . in 8

cd "D:\Inequality Urban Form\Results for APPAM"

foreach d in core peri {

//	dissimilarity graphs
	//	owner v renter
	twoway (connected d_index_avg_`d'_owner year, msymbol(square)) ///
		   /*(connected d_index_avg_`d'_mf year, msymbol(circle))*/, ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_owner_`d'.gph, replace 
	graph export 20251026_dissim_owner_`d'.png, as(png) replace
	//	sf v mf
	twoway (connected d_index_avg_`d'_sf year, msymbol(square)) ///
		   (connected d_index_avg_`d'_mf year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_sfmf_`d'.gph, replace 
	graph export 20251026_dissim_sfmf_`d'.png, as(png) replace
	//	old v new
	twoway (connected d_index_avg_`d'_old year, msymbol(square)) ///
		   (connected d_index_avg_`d'_new year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_oldnew_`d'.gph, replace 
	graph export 20251026_dissim_oldnew_`d'.png, as(png) replace
	//	vacant
	twoway (connected d_index_avg_`d'_vacant year, msymbol(square)) ///
		   /*(connected d_index_avg_`d'_mf year, msymbol(circle))*/, ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_dissim_vacant_`d'.gph, replace 
	graph export 20251026_dissim_vacant_`d'.png, as(png) replace

//	isolation graphs
	//	owner v renter
	twoway (connected iso_group1_avg_`d'_owner year, msymbol(square)) ///
		   /*(connected iso_group1_avg_`d'_mf year, msymbol(circle))*/, ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_owner_`d'.gph, replace 
	graph export 20251026_iso_owner_`d'.png, as(png) replace
	//	sf v mf
	twoway (connected iso_group1_avg_`d'_sf year, msymbol(square)) ///
		   (connected iso_group1_avg_`d'_mf year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_sfmf_`d'.gph, replace 
	graph export 20251026_iso_sfmf_`d'.png, as(png) replace
	//	old v new
	twoway (connected iso_group1_avg_`d'_old year, msymbol(square)) ///
		   (connected iso_group1_avg_`d'_new year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_oldnew_`d'.gph, replace 
	graph export 20251026_iso_oldnew_`d'.png, as(png) replace
	//	vacant
	twoway (connected iso_group1_avg_`d'_vacant year, msymbol(square)) ///
		   /*(connected iso_group1_avg_`d'_mf year, msymbol(circle))*/, ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251026_iso_vacant_`d'.gph, replace 
	graph export 20251026_iso_vacant_`d'.png, as(png) replace
}	

/*
//	older version that compared core and peri
foreach var in mf new old owner sf vacant {
	//	dissimilarity graph
	twoway (connected d_index_avg_core_`var' year, msymbol(square)) ///
		   (connected d_index_avg_peri_`var' year, msymbol(circle)), ///
		   ytitle(Dissimilarity) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Dissimilarity Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251023_dissim_`var'_coreperi.gph, replace 
	graph export 20251023_dissim_`var'_coreperi.png, as(png) replace

	//	isolation graph
	twoway (connected iso_group1_avg_core_`var' year, msymbol(square)) ///
		   (connected iso_group1_avg_peri_`var' year, msymbol(circle)), ///
		   ytitle(Isolation) /*yscale(range(.47 .53)) ylabel(.47(.01).53, grid)*/ ///
		   xtitle(Year) ///
		   title("Isolation Index", size(medium)) ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical)) legend(size(vsmall))
	graph save 20251023_iso_`var'_coreperi.gph, replace 
	graph export 20251023_iso_`var'_coreperi.png, as(png) replace
}
clear
*/




//	diversity using hhi

/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
metro_rank

merge 1:1 full_puma_matched year using ///
	"D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation\segregation_hhi_G2.dta", ///
	generate(_merge_hhi)
drop if _merge_hhi == 2



foreach s in top10 bot10 bot20 {
	preserve
		keep if metro_`s' == 1

		bysort year: egen hhi_tenure_`s' = mean(hhi_tenure)
		bysort year: egen hhi_ht_`s' = mean(hhi_ht)
		bysort year: egen hhi_yrblt_`s' = mean(hhi_yrblt)
		bysort year: egen hhi_vacant_`s' = mean(hhi_vacant)
		
		duplicates drop year, force
		
		save "D:\Inequality Urban Form\temp\hhi_slim_`s'.dta", replace
	restore
}

clear


//	assemble data for graphs
use "D:\Inequality Urban Form\temp\hhi_slim_top10.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\hhi_slim_bot10.dta", ///
	keepusing(hhi_tenure_bot10-hhi_vacant_bot10) gen(_merge_hhi_bot10)
merge 1:1 year using "D:\Inequality Urban Form\temp\hhi_slim_bot20.dta", ///
	keepusing(hhi_tenure_bot20-hhi_vacant_bot20) gen(_merge_hhi_bot20)

	
cd "D:\Inequality Urban Form\Results for APPAM"

label var hhi_tenure_top10 "Tenure diversity, 10 largest metros"
label var hhi_tenure_bot10 "Tenure diversity, 10 smallest metros"
label var hhi_tenure_bot20 "Tenure diversity, 20 smallest metros"

label var hhi_ht_top10 "Housing type diversity, 10 largest metros"
label var hhi_ht_bot10 "Housing type diversity, 10 smallest metros"
label var hhi_ht_bot20 "Housing type diversity, 20 smallest metros"

label var hhi_yrblt_top10 "Housing age diversity, 10 largest metros"
label var hhi_yrblt_bot10 "Housing age diversity, 10 smallest metros"
label var hhi_yrblt_bot20 "Housing age diversity, 20 smallest metros"

label var hhi_vacant_top10 "Vacancy diversity, 10 largest metros"
label var hhi_vacant_bot10 "Vacancy diversity, 10 smallest metros"
label var hhi_vacant_bot20 "Vacancy diversity, 20 smallest metros"

replace hhi_ht_top10 = . in 7
replace hhi_ht_bot10 = . in 7
replace hhi_ht_bot20 = . in 7


//	large and small metros
	//	hhi tenure graph
	twoway (connected hhi_tenure_top10 year, msymbol(square)) ///
		   (connected hhi_tenure_bot10 year, msymbol(circle)) ///
		   /*(connected hhi_tenure_bot20 year, msymbol(T))*/, ///
		   ytitle(Tenure Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Tenure diversity in small and large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_tenure_largesmall.gph, replace 
	graph export 20251028_hhi_tenure_largesmall.png, as(png) replace
	
	//	hhi housing type
	twoway (connected hhi_ht_top10 year, msymbol(square)) ///
		   (connected hhi_ht_bot10 year, msymbol(circle)) ///
		   /*(connected hhi_ht_bot20 year, msymbol(T))*/, ///
		   ytitle(Type Diversity) ///
		   xtitle(Year) legend(size(vsmall)) ///
		   title("Housing type diversity in small and large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_ht_largesmall.gph, replace 
	graph export 20251028_hhi_ht_largesmall.png, as(png) replace
	
	//	hhi year built
	twoway (connected hhi_yrblt_top10 year, msymbol(square)) ///
		   (connected hhi_yrblt_bot10 year, msymbol(circle)) ///
		   /*(connected hhi_yrblt_bot20 year, msymbol(T))*/, ///
		   ytitle(Age Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing age diversity in small and large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_yrblt_largesmall.gph, replace 
	graph export 20251028_hhi_yrblt_largesmall.png, as(png) replace
	
	//	hhi vacant
	twoway (connected hhi_vacant_top10 year, msymbol(square)) ///
		   (connected hhi_vacant_bot10 year, msymbol(circle)) ///
		   /*(connected hhi_vacant_bot20 year, msymbol(T))*/, ///
		   ytitle(Vacancy Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in small and large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_vacant_largesmall.gph, replace 
	graph export 20251028_hhi_vacant_largesmall.png, as(png) replace
	
	
	//	slightly different formating for paper	//
	
	//	hhi ht large metros
	twoway (connected hhi_ht_top10 year, msymbol(square)), ///
		   ytitle(Housing Type Diversity) yscale(range(.34 .54)) ylabel(.34(.02).54, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing Type diversity in large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_ht_large.gph, replace 
	graph export 20251106_hhi_ht_large.png, as(png) replace
	//	hhi ht small metros
	twoway (connected hhi_ht_bot10 year, msymbol(square)), ///
		   ytitle(Housing Type Diversity) yscale(range(.34 .54)) ylabel(.34(.02).54, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing Type diversity in small metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_ht_small.gph, replace 
	graph export 20251106_hhi_ht_small.png, as(png) replace
	
	//	hhi year built large metros
	twoway (connected hhi_yrblt_top10 year, msymbol(square)), ///
		   ytitle(Age Diversity) yscale(range(.14 .26)) ylabel(.14(.01).26, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Age diversity in large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_yrblt_large.gph, replace 
	graph export 20251106_hhi_yrblt_large.png, as(png) replace
	//	hhi year built small metros
	twoway (connected hhi_yrblt_bot10 year, msymbol(square)), ///
		   ytitle(Age Diversity) yscale(range(.14 .26)) ylabel(.14(.01).26, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Age diversity in small metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_yrblt_small.gph, replace 
	graph export 20251106_hhi_yrblt_small.png, as(png) replace
	
	//	hhi vacant large metros
	twoway (connected hhi_vacant_top10 year, msymbol(square)), ///
		   ytitle(Vacancy Diversity) yscale(range(.8 .9)) ylabel(.8(.01).9, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in large metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_vacant_large.gph, replace 
	graph export 20251106_hhi_vacant_large.png, as(png) replace
	//	hhi vacant small metros
	twoway (connected hhi_vacant_bot10 year, msymbol(square)), ///
		   ytitle(Vacancy Diversity) yscale(range(.8 .9)) ylabel(.8(.01).9, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in small metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_vacant_small.gph, replace 
	graph export 20251106_hhi_vacant_small.png, as(png) replace
	

clear

	
//	booming v distressed metros
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
metro_rank

merge 1:1 full_puma_matched year using ///
	"D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation\segregation_hhi_G2.dta", ///
	generate(_merge_hhi)
drop if _merge_hhi == 2

preserve
	keep if SLLM_Distress_Ranking == 1

	bysort year: egen hhi_tenure_boom = mean(hhi_tenure)
	bysort year: egen hhi_ht_boom = mean(hhi_ht)
	bysort year: egen hhi_yrblt_boom = mean(hhi_yrblt)
	bysort year: egen hhi_vacant_boom = mean(hhi_vacant)
	
	duplicates drop year, force
	
	save "D:\Inequality Urban Form\temp\hhi_slim_boom.dta", replace
restore

preserve
	keep if SLLM_Distress_Ranking != 1 & SLLM_Distress_Ranking != .

	bysort year: egen hhi_tenure_dist = mean(hhi_tenure)
	bysort year: egen hhi_ht_dist = mean(hhi_ht)
	bysort year: egen hhi_yrblt_dist = mean(hhi_yrblt)
	bysort year: egen hhi_vacant_dist = mean(hhi_vacant)
	
	duplicates drop year, force
	
	save "D:\Inequality Urban Form\temp\hhi_slim_dist.dta", replace
restore

clear


//	assemble data for graphs
use "D:\Inequality Urban Form\temp\hhi_slim_boom.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\hhi_slim_dist.dta", ///
	keepusing(hhi_tenure_dist-hhi_vacant_dist) gen(_merge_hhi_dist)

	
cd "D:\Inequality Urban Form\Results for APPAM"

label var hhi_tenure_boom "Tenure diversity, booming metros"
label var hhi_tenure_dist "Tenure diversity, distressed metros"

label var hhi_ht_boom "Housing type diversity, booming metros"
label var hhi_ht_dist "Housing type diversity, distressed metros"

label var hhi_yrblt_boom "Housing age diversity, booming metros"
label var hhi_yrblt_dist "Housing age diversity, distressed metros"

label var hhi_vacant_boom "Vacancy diversity, booming metros"
label var hhi_vacant_dist "Vacancy diversity, distressed metros"


replace hhi_ht_boom = . in 7
replace hhi_ht_dist = . in 7


	//	hhi tenure graph
	twoway (connected hhi_tenure_boom year, msymbol(square)) ///
		   (connected hhi_tenure_dist year, msymbol(circle)) ///
		   /*(connected hhi_tenure_bot20 year, msymbol(T))*/, ///
		   ytitle(Tenure Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Tenure diversity in booming and distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_tenure_boomdist.gph, replace 
	graph export 20251028_hhi_tenure_boomdist.png, as(png) replace
	
	//	hhi housing type
	twoway (connected hhi_ht_boom year, msymbol(square)) ///
		   (connected hhi_ht_dist year, msymbol(circle)) ///
		   /*(connected hhi_ht_bot20 year, msymbol(T))*/, ///
		   ytitle(Type Diversity) ///
		   xtitle(Year) legend(size(vsmall)) ///
		   title("Housing type diversity in booming and distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_ht_boomdist.gph, replace 
	graph export 20251028_hhi_ht_boomdist.png, as(png) replace
	
	//	hhi year built
	twoway (connected hhi_yrblt_boom year, msymbol(square)) ///
		   (connected hhi_yrblt_dist year, msymbol(circle)) ///
		   /*(connected hhi_yrblt_bot20 year, msymbol(T))*/, ///
		   ytitle(Age Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing age diversity in booming and distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_yrblt_boomdist.gph, replace 
	graph export 20251028_hhi_yrblt_boomdist.png, as(png) replace
	
	//	hhi vacant
	twoway (connected hhi_vacant_boom year, msymbol(square)) ///
		   (connected hhi_vacant_dist year, msymbol(circle)) ///
		   /*(connected hhi_vacant_bot20 year, msymbol(T))*/, ///
		   ytitle(Vacancy Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in booming and distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_vacant_boomdist.gph, replace 
	graph export 20251028_hhi_vacant_boomdist.png, as(png) replace
	
	
	
	//	slightly different formating for paper	//
	
	//	hhi ht booming metros
	twoway (connected hhi_ht_boom year, msymbol(square)), ///
		   ytitle(Housing Type Diversity) yscale(range(.36 .44)) ylabel(.36(.01).44, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing Type diversity in booming metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_ht_boom.gph, replace 
	graph export 20251106_hhi_ht_boom.png, as(png) replace
	//	hhi tenure distressed metros
	twoway (connected hhi_ht_dist year, msymbol(square)), ///
		   ytitle(Housing Type Diversity) yscale(range(.36 .44)) ylabel(.36(.01).44, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing Type diversity in distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_ht_dist.gph, replace 
	graph export 20251106_hhi_ht_dist.png, as(png) replace
	
	//	hhi year built booming metros
	twoway (connected hhi_yrblt_boom year, msymbol(square)), ///
		   ytitle(Age Diversity) yscale(range(.16 .26)) ylabel(.16(.01).26, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Age diversity in booming metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_yrblt_boom.gph, replace 
	graph export 20251106_hhi_yrblt_boom.png, as(png) replace
	//	hhi year built distressed metros
	twoway (connected hhi_yrblt_dist year, msymbol(square)), ///
		   ytitle(Age Diversity) yscale(range(.16 .26)) ylabel(.16(.01).26, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Age diversity in distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_yrblt_dist.gph, replace 
	graph export 20251106_hhi_yrblt_dist.png, as(png) replace
	
	//	hhi vacant booming metros
	twoway (connected hhi_vacant_boom year, msymbol(square)), ///
		   ytitle(Vacancy Diversity) yscale(range(.81 .92)) ylabel(.81(.01).92, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in booming metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_vacant_boom.gph, replace 
	graph export 20251106_hhi_vacant_boom.png, as(png) replace
	//	hhi vacant distressed metros
	twoway (connected hhi_vacant_dist year, msymbol(square)), ///
		   ytitle(Vacancy Diversity) yscale(range(.81 .92)) ylabel(.81(.01).92, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in distressed metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_vacant_dist.gph, replace 
	graph export 20251106_hhi_vacant_dist.png, as(png) replace

clear
	
	
//	core v peripheral metros
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
metro_rank

merge 1:1 full_puma_matched year using ///
	"D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation\segregation_hhi_G2.dta", ///
	generate(_merge_hhi)
drop if _merge_hhi == 2

preserve
	keep if buildable_pct < 5.25

	bysort year: egen hhi_tenure_core = mean(hhi_tenure)
	bysort year: egen hhi_ht_core = mean(hhi_ht)
	bysort year: egen hhi_yrblt_core = mean(hhi_yrblt)
	bysort year: egen hhi_vacant_core = mean(hhi_vacant)
	
	duplicates drop year, force
	
	save "D:\Inequality Urban Form\temp\hhi_slim_core.dta", replace
restore

preserve
	keep if buildable_pct > 54

	bysort year: egen hhi_tenure_peri = mean(hhi_tenure)
	bysort year: egen hhi_ht_peri = mean(hhi_ht)
	bysort year: egen hhi_yrblt_peri = mean(hhi_yrblt)
	bysort year: egen hhi_vacant_peri = mean(hhi_vacant)
	
	duplicates drop year, force
	
	save "D:\Inequality Urban Form\temp\hhi_slim_peri.dta", replace
restore

clear


//	assemble data for graphs
use "D:\Inequality Urban Form\temp\hhi_slim_core.dta"
merge 1:1 year using "D:\Inequality Urban Form\temp\hhi_slim_peri.dta", ///
	keepusing(hhi_tenure_peri-hhi_vacant_peri) gen(_merge_hhi_peri)

	
cd "D:\Inequality Urban Form\Results for APPAM"

label var hhi_tenure_core "Tenure diversity, built up PUMAs"
label var hhi_tenure_peri "Tenure diversity, lower density PUMAs"

label var hhi_ht_core "Housing type diversity, built up PUMAs"
label var hhi_ht_peri "Housing type diversity, distressed PUMAs"

label var hhi_yrblt_core "Housing age diversity, built up PUMAs"
label var hhi_yrblt_peri "Housing age diversity, distressed PUMAs"

label var hhi_vacant_core "Vacancy diversity, built up PUMAs"
label var hhi_vacant_peri "Vacancy diversity, distressed PUMAs"


replace hhi_ht_core = . in 7
replace hhi_ht_peri = . in 7


	//	hhi tenure graph
	twoway (connected hhi_tenure_core year, msymbol(square)) ///
		   (connected hhi_tenure_peri year, msymbol(circle)) ///
		   /*(connected hhi_tenure_bot20 year, msymbol(T))*/, ///
		   ytitle(Tenure Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Tenure diversity in built up and low density PUMAs") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_tenure_coreperi.gph, replace 
	graph export 20251028_hhi_tenure_coreperi.png, as(png) replace
	
	//	hhi housing type
	twoway (connected hhi_ht_core year, msymbol(square)) ///
		   (connected hhi_ht_peri year, msymbol(circle)) ///
		   /*(connected hhi_ht_bot20 year, msymbol(T))*/, ///
		   ytitle(Type Diversity) ///
		   xtitle(Year) legend(size(vsmall)) ///
		   title("Housing type diversity in built up and low density PUMAs") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_ht_coreperi.gph, replace 
	graph export 20251028_hhi_ht_coreperi.png, as(png) replace
	
	//	hhi year built
	twoway (connected hhi_yrblt_core year, msymbol(square)) ///
		   (connected hhi_yrblt_peri year, msymbol(circle)) ///
		   /*(connected hhi_yrblt_bot20 year, msymbol(T))*/, ///
		   ytitle(Age Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing age diversity in built up and low density PUMAs") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_yrblt_coreperi.gph, replace 
	graph export 20251028_hhi_yrblt_coreperi.png, as(png) replace
	
	//	hhi vacant
	twoway (connected hhi_vacant_core year, msymbol(square)) ///
		   (connected hhi_vacant_peri year, msymbol(circle)) ///
		   /*(connected hhi_vacant_bot20 year, msymbol(T))*/, ///
		   ytitle(Vacancy Diversity) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in built up and low density PUMAs") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251028_hhi_vacant_coreperi.gph, replace 
	graph export 20251028_hhi_vacant_coreperi.png, as(png) replace
	
	
	
	//	slightly different formating for paper	//
	
	//	hhi tenure core metros
	twoway (connected hhi_ht_core year, msymbol(square)), ///
		   ytitle(Housing Type Diversity) yscale(range(.30 .56)) ylabel(.30(.02).56, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing Type diversity in built up metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_ht_core.gph, replace 
	graph export 20251106_hhi_ht_core.png, as(png) replace
	//	hhi tenure peri metros
	twoway (connected hhi_ht_peri year, msymbol(square)), ///
		   ytitle(Housing Type Diversity) yscale(range(.30 .56)) ylabel(.30(.02).56, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Housing Type diversity in less dense metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_ht_peri.gph, replace 
	graph export 20251106_hhi_ht_peri.png, as(png) replace
	
	//	hhi year built core metros
	twoway (connected hhi_yrblt_core year, msymbol(square)), ///
		   ytitle(Age Diversity) yscale(range(.15 .30)) ylabel(.15(.01).30, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Age diversity in built up metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_yrblt_core.gph, replace 
	graph export 20251106_hhi_yrblt_core.png, as(png) replace
	//	hhi year built distressed metros
	twoway (connected hhi_yrblt_peri year, msymbol(square)), ///
		   ytitle(Age Diversity) yscale(range(.15 .30)) ylabel(.15(.01).30, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Age diversity in less dense metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_yrblt_peri.gph, replace 
	graph export 20251106_hhi_yrblt_peri.png, as(png) replace
	
	//	hhi vacant core metros
	twoway (connected hhi_vacant_core year, msymbol(square)), ///
		   ytitle(Vacancy Diversity) yscale(range(.82 .90)) ylabel(.82(.01).90, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in built up metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_vacant_core.gph, replace 
	graph export 20251106_hhi_vacant_core.png, as(png) replace
	//	hhi vacant distressed metros
	twoway (connected hhi_vacant_peri year, msymbol(square)), ///
		   ytitle(Vacancy Diversity) yscale(range(.82 .90)) ylabel(.82(.01).90, grid) ///
		   xtitle(Year) legend(size(small)) ///
		   title("Vacancy diversity in less dense metros") ///
		   xlabel(1990 2000 2005 2008 2010 2012 2015 2019 2021 2022, ///
		   grid angle (vertical))
	graph save 20251106_hhi_vacant_peri.gph, replace 
	graph export 20251106_hhi_vacant_peri.png, as(png) replace
	
clear



	
//	regressions
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/
metro_rank
replace persons = persons/1e3
replace persons_hh = persons_hh/1e3

merge 1:1 full_puma_matched year using ///
	"D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation\segregation_hhi_G2.dta", ///
	generate(_merge_hhi)
drop if _merge_hhi == 2

//	the multi-group hhi vars are:
*	hhi_tenure
*	hhi_ht 
*	hhi_yrblt 
*	hhi_vacant

label define yearlbl 2008 "2008-2015" ///
                     2010 "2010-2017" ///
                     2012 "2012-2019" ///
                     2015 "2015-2022"

label values year yearlbl

cd "D:\Inequality Urban Form\Results for APPAM\scatter"

//	3.1.1 & 3.1.2
foreach typo in vacant owner mf sfr_detached new old {
    foreach metric in p_group1 d_index iso_group1 /*hhi*/ {
    	local xvar `metric'_`typo'
        * 3.1.1. Output: Panel scatterplots for two periods:
        * 2012-2019, main specification where all 2012 PUMAs available
        * 2008-2015, covering two 5-year ACS waves 
	    twoway (scatter puma_theilLD_7 `metric'_`typo', ///
			msize(vsmall) mcolor(navy%10)) ///
	        (lfit puma_theilLD_7 `metric'_`typo') if ///
	        !missing(puma_giniLD_7) & inrange(year, 2006, 2014), by(year) ///
            name(`xvar', replace) ///
			ytitle(7-year change in PUMA Theil) ///
			xtitle(`metric') legend(size(small))
		graph export `xvar'.png, as(png) replace
        * Univariate regressions reflecting fitted lines in scatterplots
        * (But also with MSA population controls added)
        reghdfe puma_theilLD_7 c.`xvar'##ib2012.year (c.persons c.persons_hh)##year ///
            if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
		eststo `xvar'_01
    
    graph close
	    
    * 3.1.2 Output:  "horserace regression" with both a term for shares and
    * a term for spatial segregation. (This is tested for two-class measures
    * only. Multi-class probably uses hhi and mi_index.)
    reghdfe puma_theilLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), ///
		absorb(year) cluster(panel_id)
	eststo `xvar'_02
	
    * Robustness 1 - do results hold with a two-class HHI measure?
    reghdfe puma_theilLD_7 (c.hhi_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), ///
		absorb(year) cluster(panel_id)
	eststo `xvar'_03
	
    * Robustness 2 - do results disappear with metro employment distress ctrl?
    reghdfe puma_theilLD_7 (c.hhi_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh c.SLLMPrime)##year if !missing(puma_giniLD_7), ///
        absorb(year) cluster(panel_id)
		eststo `xvar'_04
		
	esttab `xvar'_01 `xvar'_02 `xvar'_03 `xvar'_04 using `xvar'.csv, ///
		se r2 b(3) se(3) label replace

	}
}
eststo clear


//	separate loop for hhi
foreach typo in tenure ht yrblt vacant {
    local xvar hhi_`typo'
        * 3.1.1. Output: Panel scatterplots for two periods:
        * 2012-2019, main specification where all 2012 PUMAs available
        * 2008-2015, covering two 5-year ACS waves 
	    twoway (scatter puma_theilLD_7 hhi_`typo', ///
			msize(vsmall) mcolor(navy%10)) ///
	        (lfit puma_theilLD_7 hhi_`typo') if ///
	        !missing(puma_giniLD_7) & inrange(year, 2006, 2014), by(year) ///
            name(`xvar', replace) ///
			ytitle(7-year change in PUMA Theil) ///
			xtitle("HHI") legend(size(small))
		graph export `xvar'.png, as(png) replace
        * Univariate regressions reflecting fitted lines in scatterplots
        * (But also with MSA population controls added)
        reghdfe puma_theilLD_7 c.`xvar'##ib2012.year (c.persons c.persons_hh)##year ///
            if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
		eststo `xvar'_01
    
    graph close
	
    * 3.1.2 Output:  "horserace regression" with both a term for shares and
    * a term for spatial segregation. (This is tested for two-class measures
    * only. Multi-class probably uses hhi and mi_index.)
    /*reghdfe puma_theilLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
	
    * Robustness 1 - do results hold with a multi-class HHI measure?
    reghdfe puma_theilLD_7 (c.hhi_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
	eststo `xvar'_02
	*/
    * Robustness 2 - do results disappear with metro employment distress ctrl?
    reghdfe puma_theilLD_7 (c.hhi_`typo')##ib2012.year ///
        (c.persons c.persons_hh c.SLLMPrime)##year if !missing(puma_giniLD_7), ///
        absorb(year) cluster(panel_id)
	eststo `xvar'_02
	
	esttab `xvar'_01 `xvar'_02 using `xvar'.csv, ///
		se r2 b(3) se(3) label replace 

}

eststo clear
label drop yearlbl



//	3.1.3
* We can take the BaumSnow-Han elasticities aggregated to PUMA level, and
* see how associated our built form measures are to it.
foreach metric in p_group1 d_index iso_group1 hhi {
    corr puma_theil def1_*_units_FMM `metric'_*  buildable_pct if inrange(year, 2008, 2012)
}

* TAKEAWAY: Can aggregate based on different base years, different methods
* as suggested in BH paper, and using floorspace vs. units. But correlation
* changes little.
corr def?_*_units_FMM p_group1_*  buildable_pct if inrange(year, 2008, 2012)
corr def?_*_space_FMM p_group1_*  buildable_pct if inrange(year, 2008, 2012)









//	side graph for group shares
/*
cd "D:\Inequality Urban Form\Tom Data\Core_Data\ineq_merged"
use incineq_seg_mkstats_full_G2.dta
*/

merge 1:1 full_puma_matched year using ///
	"D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation\segregation_ht_hhi_wide_G2.dta", ///
	keepusing(p_group1- p_group10) generate(_merge_groupshare_ht)
drop if _merge_groupshare_ht==2
renvars p_group1- p_group10, suffix(_ht)

merge 1:1 full_puma_matched year using ///
	"D:\Inequality Urban Form\Tom Data\Core_Data\rhs_within_puma\segregation\segregation_yrblt_hhi_wide_G2.dta", ///
	keepusing(p_group1- p_group10) generate(_merge_groupshare_yrblt)
drop if _merge_groupshare_yrblt==2
renvars p_group1- p_group10, suffix(_yrblt)

//	shares in all pumas	
tabstat p_group1_ht-p_group10_ht p_group1_yrblt-p_group10_yrblt, ///
	statistics(mean p50) columns(stats) /*by(year)*/

//	large v small metros
preserve
	keep if metro_top10 == 1
	tabstat p_group1_ht-p_group10_ht p_group1_yrblt-p_group10_yrblt, ///
	statistics(mean) columns(stats) /*by(year)*/
restore

preserve
	keep if metro_bot20 == 1
	tabstat p_group1_ht-p_group10_ht p_group1_yrblt-p_group10_yrblt, ///
	statistics(mean) columns(stats) /*by(year)*/
restore

//	booming v distressed metros
preserve
	keep if SLLM_Distress_Ranking == 1
	tabstat p_group1_ht-p_group10_ht p_group1_yrblt-p_group10_yrblt, ///
	statistics(mean) columns(stats) /*by(year)*/
restore

preserve
	keep if SLLM_Distress_Ranking != 1 & SLLM_Distress_Ranking != .
	tabstat p_group1_ht-p_group10_ht p_group1_yrblt-p_group10_yrblt, ///
	statistics(mean) columns(stats) /*by(year)*/
restore

//	core v peri metros
preserve
	keep if buildable_pct < 5.25
	tabstat p_group1_ht-p_group10_ht p_group1_yrblt-p_group10_yrblt, ///
	statistics(mean) columns(stats) /*by(year)*/
restore

preserve
	keep if buildable_pct > 54
	tabstat p_group1_ht-p_group10_ht p_group1_yrblt-p_group10_yrblt, ///
	statistics(mean) columns(stats) /*by(year)*/
restore





	
/*

preserve
keep if metro_top10 == 1
bysort year: sum(d_index_mf d_index_new d_index_old d_index_owner d_index_sfr_detached d_index_vacant ///
				iso_group1_mf iso_group1_new iso_group1_old iso_group1_owner iso_group1_sfr_detached iso_group1_vacant ///
				p_group1_mf p_group1_new p_group1_old p_group1_owner p_group1_sfr_detached p_group1_vacant)
restore
preserve
keep if metro_bot20 == 1
bysort year: sum(d_index_mf d_index_new d_index_old d_index_owner d_index_sfr_detached d_index_vacant ///
				iso_group1_mf iso_group1_new iso_group1_old iso_group1_owner iso_group1_sfr_detached iso_group1_vacant ///
				p_group1_mf p_group1_new p_group1_old p_group1_owner p_group1_sfr_detached p_group1_vacant)
restore


//	correlation between 1 or 2 inequality measures and segregation, by
//	top and bottom 10 cities and year

preserve
keep if metro_top10 == 1
foreach y in 1990 2000 2012 2022 {
	pwcorr	met_theil_within puma_theil p99p90_p p50p10_p ///
			d_index_mf d_index_new d_index_owner d_index_sfr_detached d_index_vacant ///
			iso_group1_mf iso_group1_new iso_group1_owner iso_group1_sfr_detached iso_group1_vacant ///
			p_group1_mf p_group1_new p_group1_owner p_group1_sfr_detached p_group1_vacant ///
			if year == `y', star(0.05)
	}
restore
preserve
keep if metro_bot10 == 1
foreach y in 1990 2000 2012 2022 {
	pwcorr	met_theil_within puma_theil p99p90_p p50p10_p ///
			d_index_mf d_index_new d_index_owner d_index_sfr_detached d_index_vacant ///
			iso_group1_mf iso_group1_new iso_group1_owner iso_group1_sfr_detached iso_group1_vacant ///
			p_group1_mf p_group1_new p_group1_owner p_group1_sfr_detached p_group1_vacant ///
			if year == `y', star(0.05)
	}
restore






