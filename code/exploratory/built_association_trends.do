/*

   FILENAME: built_association_trends.do
   This is an exploratory file by TC to run the specifications we
   propose in the outline, as well to understand if some versions
   of our built environment metrics are more predictive than others.

*/



/* LOAD IN DATA */
use incineq_seg_mkstats_full_G2.dta, clear
replace persons = persons/1e3
replace persons_hh = persons_hh/1e3


/* ITERATE ANALYSIS FOR SUBSECTIONS 3.1.1, 3.1.2 FOR CANDIDATE METRICS */

foreach typo in vacant owner mf sfr_detached {
    foreach metric in p_group1 d_index iso_group1 hhi {
    	local xvar `metric'_`typo'
        * 3.1.1. Output: Panel scatterplots for two periods:
        * 2012-9, main specification where all 2012 PUMAs available
        * 2008-2015, covering two 5-year ACS waves 
	    twoway (scatter puma_theilLD_7 `xvar', msize(vsmall) mcolor(navy%10)) ///
	        (lfit puma_theilLD_7 `xvar') if ///
	        !missing(puma_giniLD_7) & inrange(year, 2006, 2014), by(year) ///
            name(`xvar', replace)
        graph export "built_association_out/`xvar'.pdf", as(pdf) replace
        * Univariate regressions reflecting fitted lines in scatterplots
        * (But also with MSA population controls added)
        reghdfe puma_theilLD_7 c.`xvar'##ib2012.year (c.persons c.persons_hh)##year ///
            if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
    }
    graph close
    
    * 3.1.2 Output:  "horserace regression" with both a term for shares and
    * a term for spatial segregation. (This is tested for two-class measures
    * only. Multi-class probably uses hhi and mi_index.)
    reghdfe puma_theilLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
	
    * Robustness 1 - do results hold with a two-class HHI measure?
    reghdfe puma_theilLD_7 (c.hhi_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
	
    * Robustness 2 - do results disappear with metro employment distress ctrl?
    reghdfe puma_theilLD_7 (c.hhi_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh c.SLLMPrime)##year if !missing(puma_giniLD_7), ///
        absorb(year) cluster(panel_id)
    /*
        TAKEAWAYS:
	    - Share and segregation measures of vacant homes have no significant
             associations of note.
        - Share of owner-occupied housing has POSITIVE association with PUMA
             theil across specifications. Segregation measures, by diversity
             index, lacks significant associations. (Tom has tried isolation
             index as well, results are not much more significant.)
          [It might be good to use RENTER-occupied measure instead: would
            the signs all flip but magnitudes remain the same?]
        - Share of multifamily housing lacks significant association. Diversity
             index of multifamily has POSITIVE association (but it's close to 95%
             significant only.)
        - Both the SHARE and DIVERSITY INDEX of single-family detached homes
             have significant POSITIVE associations (but it's close to 95%
             significant only.)
    */
}


* We separate out two cases: newer homes built only after 2000 and older homes
* built only before 1940. Unlike with earlier vars, we're excluding the significant
* share of homes built between those years. We'll try to include them with
* a multiclass Herfindahl index.
foreach typo in new old {
    foreach metric in p_group1 d_index iso_group1 hhi {
    	local xvar `metric'_`typo'
        twoway (scatter puma_theilLD_7 `xvar', msize(vsmall) mcolor(navy%10)) ///
            (lfit puma_theilLD_7 `xvar') if ///
            !missing(puma_giniLD_7) & inrange(year, 2006, 2014), by(year) name(`xvar', replace)
        graph export "built_association_out/`xvar'.pdf", as(pdf) replace
        reghdfe puma_theilLD_7 c.`xvar'##ib2012.year (c.persons c.persons_hh)##year ///
            if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
    }
    graph close
    reghdfe puma_theilLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
	
    reghdfe puma_theilLD_7 (c.hhi_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
	
    reghdfe puma_theilLD_7 (c.hhi_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh c.SLLMPrime)##year if !missing(puma_giniLD_7), ///
        absorb(year) cluster(panel_id)
    /*
        TAKEAWAYS:
        
        Diversity measures of homes by years built tend not to have significant
            associations.
        The association with share variables can FLIP SIGN depending on if we're
            using just the raw share or 2-class Herfindahl index. Hard to
            conclude anything from that.
	
	
    */
}


/* PRELIMINARY ANALYSIS FOR SUBSECTION 3.1.3
   (Down the line, we may argue that if our built form metrics correlate with
    BaumSnow-Han elasticities, they're easier to calculate outside of non-US contexts.)
*/

* We can take the BaumSnow-Han elasticities aggregated to PUMA level, and
* see how associated our built form measures are to it.
foreach metric in p_group1 d_index iso_group1 hhi {
    corr def1_*_units_FMM `metric'_*  buildable_pct if inrange(year, 2008, 2012)
    /*
        TAKEAWAYS:
	
	    In general, share-based measures of housing diversity are more
        strongly correlated with the BH elasticities. (Wouldn't be surprised
        if they ran this already.)
        Diversity based measures are not completely uncorrelated, just weaker.
        But diversity measure correlations of note include d_index_mf (so
        more segregated Multifamily -> more elastic) and d_index_new (more
        segregated siting of new housing -> more inelastic)
    */
}

* TAKEAWAY: Can aggregate based on different base years, different methods
* as suggested in BH paper, and using floorspace vs. units. But correlation
* changes little.
corr def?_*_units_FMM p_group1_*  buildable_pct if inrange(year, 2008, 2012)
corr def?_*_space_FMM p_group1_*  buildable_pct if inrange(year, 2008, 2012)



/* EXTENSION OF ANALYSIS IN SECTION 3.1.2 (See TOM's last paragraph)
*/

* We can generate a dummy variable for PUMAs above the median in buildable
* share of land. Tom's hypothesis is that these places have less counteracting
* displacement effects, so inequality increases more there.
sum buildable_pct, d
gen not_built_up = (buildable_pct > `r(p50)') if !missing(buildable_pct)
binscatter puma_theilLD_7 buildable_pct, by(year) control(c.persons c.persons_hh) ///
    name(not_built_up_binscatter, replace)


foreach typo in vacant owner mf sfr_detached {

    * We test the hypothesis by checking if the interaction term "#not_built_up"
    * is positive. 	
    reghdfe puma_theilLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.p_group1_`typo' c.d_index_`typo')#not_built_up not_built_up ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
    
    * As robustness, we also see if the association with ineq. at top (90/50 ratio)
    * is of the same sign as with the theil index. (That's what we'd expect, given
    * positive correlation between the two outcomes)
    reghdfe p90p50_pLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(p90p50_pLD_7), absorb(year) cluster(panel_id)
        
    * What about with ineq. at bottom (50/10 ratio)? Correlation with theil index
    * and this outcome is less than with 90/50 ratio.
    reghdfe p50p10_pLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(p50p10_pLD_7), absorb(year) cluster(panel_id)

    * Can't run this regression yet - long diff not generated.
    * TODO should do so in the earlier script where all other LD vars are generated.
    *reghdfe p10_pLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
    *    (c.persons c.persons_hh)##year if !missing(p50p10_pLD_7), absorb(year) cluster(panel_id)
    
    /*
        TAKEAWAYS:
	  - Still nothing with vacant.
      - With owner and sfr_detached, the share term which was significant earlier
           also has a POSITIVE interaction association with not_built_up.
      - No association is meaningful for the multifamily measures.
      - Owner diversity index is POSITIVELY associated with inequality at the bottom,
           and no other results of note really with that outcome.
	
    */
}


foreach typo in new old {
	
    reghdfe puma_theilLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.p_group1_`typo' c.d_index_`typo')#not_built_up not_built_up ///
        (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)
    
    reghdfe p90p50_pLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(p90p50_pLD_7), absorb(year) cluster(panel_id)

    reghdfe p50p10_pLD_7 (c.p_group1_`typo' c.d_index_`typo')##ib2012.year ///
        (c.persons c.persons_hh)##year if !missing(p50p10_pLD_7), absorb(year) cluster(panel_id)
    /*
        TAKEAWAYS:
	
      - Diversity index for older homes is POSITIVELY associated with inequality
            at the bottom.
      - No other clear results of note.	    
    */
}


/* EXECUTE ANALYSIS IN 3.1.3 DIRECTLY */

* What if we ran everything on the Baum-Snow-Han local elasticities directly?
* We use the measure based on 2000s data, in unit terms, elasticity-biased
* (In practices, aggregated up the correlation between them is very strong)
	
 
reghdfe puma_theilLD_7 c.def2_gamma01b_units_FMM##ib2012.year ///
    (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)

reghdfe puma_theilLD_7 c.def2_gamma01b_units_FMM##ib2012.year ///
    c.def2_gamma01b_units_FMM#not_built_up not_built_up ///
    (c.persons c.persons_hh)##year if !missing(puma_giniLD_7), absorb(year) cluster(panel_id)

reghdfe p90p50_pLD_7 c.def2_gamma01b_units_FMM##ib2012.year ///
    (c.persons c.persons_hh)##year if !missing(p90p50_pLD_7), absorb(year) cluster(panel_id)

reghdfe p50p10_pLD_7 c.def2_gamma01b_units_FMM##ib2012.year ///
    (c.persons c.persons_hh)##year if !missing(p50p10_pLD_7), absorb(year) cluster(panel_id)
/*
    TAKEAWAYS:

    - Higher values of the local elasticities (so MORE elastic) is POSITIVELY
      associated with theil index inequality. (Tom thinks this makes sense. Places
      with elastic housing supply accomodates high-income newcomers without displacing
      people at bottom of distribution. Continued presence of both increases community
      inequality.)
    - However, we also find a positive effect to be anomalous for just the 2012-19 data.
      Associations over any other year's long differences are much weaker?
    
    - The interaction effect on not_built_up is not strong, but this is also intuitive:
      the correlations we observed between elastic PUMAs and not built up PUMAs
      generate multicollinearity between those two.
    - The positive association with inequality at the top (p90/p50) is more
      significant than with inequality at bottom (p50/p10)
*/

