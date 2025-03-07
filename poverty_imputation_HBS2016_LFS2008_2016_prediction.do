/*******************************************

1. prepare HBS2016 data
2. impute missing explanatory values
3. estimate the consumption model
4. save it for later prediction with LFS

*/******************************************
use "https://www.dropbox.com/s/kpniuza3u0ezo3t/LCA_2016_SLCHB_v01_M_v01_A_SEDLAC-03__deflated_all.dta?dl=1", clear
// use "Z:\Dropbox\Imputation\HBS\LCA 2016\LCA_2016_SLCHB_v01_M_v01_A_SEDLAC-03__deflated_all.dta",clear
// use "/Users/yd/Dropbox/Imputation/HBS/LCA 2016/LCA_2016_SLCHB_v01_M_v01_A_SEDLAC-03__deflated_all.dta", clear
rename (hombre edad casado nivel aedu relab region_est2 urban)(sex age married edu_level edu_year employment_type med_region urban)
rename (miembros agua elect propieta auto moto bici tv_cable lavarropas heladera precaria)(members water_access elect_access own_home car motor bike tv wash_machine fridge bad_loc)
rename (gedad1 habita dormi banio cloacas)(age_group nex_room n_bedroom toilet toilet_sewer)
rename internet_casa internet 
rename deseo_emp xtrawork
rename contrato signed_contract
rename hstrt total_hrs
rename computadora computer
rename durades mo_unemp
rename id hhid 
rename ano_ocaux year
rename relacion relation
rename pondera weight
gen nweight = weight*members

gen pcexpae_def11 = pcexpae/cpi11
gen povline_def11 = povline/cpi11
gen ln_pcexpae_def11 = log(pcexpae_def11)
egen no_dependent	   =total(age<=14), by(hhid)

recode edu_level (0  =1 no_school)(1/2=2 primary)(3/4=3 secondary)(5/6 = 4 tertiary) (else=.), gen(edu_group)

gen employed 	= (ocupado==1 & desocupa==0 & age>14)
gen unemployed	= (ocupado==0 & desocupa==1 & age>14)
gen not_LF		= (employed==0 & unemployed==0 & age>14)

gen 	emp_status	 =1 if 	employed	== 1 
replace emp_status	 =2 if 	unemployed  == 1
replace emp_status	 =3 if  not_LF		== 1
label 	def			emp_status 	1 "employed" 2 "unemployed" 3 "out of LF" 
label 	val			emp_status emp_status

gen 	occupation = 1	if employment_type == 3 //self_employed 
replace occupation = 2	if employment_type == 1 //employer
replace occupation = 3	if employment_type == 2|employment_type == 4 // employee

label 	def			occupation 	1 "self employed" 2 "employer" 3 "employee"  0 "unemployed" 100 "out of LF"
label 	val			occupation occupation

drop sector
recode sector1d (1 2=1 agriculture)(4 = 2 manufacturing)(6 = 3 construction)(3 5 =4 mining_energy)(13 14 15 = 5 edu_health_social_service) ///
				(10 11 12 17= 6 professional_service)(9 = 7 tansportation)(7=8 wholesale_retail)(8 = 9 hotel_restaurants)(16 = 10 other), gen(sector)

	gen				parish = region_est1
	recode			parish (4=3) (6=4) (7=5) (8=6) (9=7) (10=8) (11=9) (12=10)
	label def		parish 	1 "Castries City" 2 "Castries Rural" 3 "Anse la Raye/Canaries" 4 "SoufriËre" ///
							5 "Choiseul" 6 "Laborie" 7 "Vieux Fort" 8 "Micoud" 9 "Dennery" 10 "Gros Islet"
	label val		parish parish
	label var		parish "District"
	drop urban
	gen				urban = (parish == 1 | parish == 2 | parish == 3 | parish == 6 | parish == 9 | parish == 12) if parish != .
	label var		urban "Urban locality"

gen member_sq = members*members
gen survey = "HBS"

global head_char "sex relation hhid married age_group edu_group emp_status sector occupation unemployed emp_status"
global hh_char "no_dependent urban parish members member_sq own_home wash_machine fridge telef n_bedroom car computer"

keep ed cpi11 povline povline_def11 pcexpae pcexpae_def11 ln_pcexpae_def11 nweight weight survey year $head_char $hh_char 

replace sector=10 if sector==4
drop if parish==0 | parish==.

replace povline 	 	=	6443 		if povline ==.
replace povline_def11	=	6067.426	if povline_def11==.

global char_cont "ln_pcexpae_def11 n_bedroom"
global char_bi "married own_home wash_machine fridge car computer"
global char_cat_uno "sector emp_status occupation"
global char_cat_o "edu_group"

// impute missing values for all necessary variables
mi set mlong
mi register imputed  $char_cont $char_bi $char_cat_uno $char_cat_o
mi impute chained (regress) $char_cont (logit) $char_bi (mlogit) $char_cat_uno (ologit) $char_cat_o = sex [pw=nweight], augment add(10) rseed(1234) force noisily 

replace sector=0	if unemployed ==1
replace sector=100	if emp_status ==3 //out of LF

replace occupation = 0		if unemployed == 1 //unemployed
replace occupation = 100	if emp_status ==	 3 //out of LF

tab age_group, gen(age_group_) 

tab edu_group, gen(edu_group_)
mi passive: egen no_no_school	   =total(edu_group_1==1), by(hhid)
mi passive: egen no_primary 	   =total(edu_group_2==1), by(hhid)
mi passive: egen no_secondary      =total(edu_group_3==1), by(hhid)
mi passive: egen no_tertiary       =total(edu_group_4==1), by(hhid)

tab occupation, gen(occupation_)
mi passive: egen no_self_employed=total(occupation_1==1), by(hhid)
mi passive: egen no_employer     =total(occupation_2==1), by(hhid)
mi passive: egen no_employee     =total(occupation_3==1), by(hhid)

tab sector, gen(sector_)
tab parish, gen(parish_)
tab emp_status, gen(emp_status_)

keep if relation==1
mi svyset 	ed	[pw=nweight], strata(parish)

global head_char "married age_group_2-age_group_5 edu_group_2-edu_group_4 sector_2-sector_9 occupation_2-occupation_3 emp_status_2 emp_status_3"
global hh_char "parish_2-parish_10 no_dependent no_self_employed no_employer no_employee no_no_school no_primary no_secondary no_tertiary members member_sq own_home wash_machine fridge telef n_bedroom car computer"

mi convert flong, clear
mi estimate, esample(touse) saving(miest, replace): svy: reg ln_pcexpae_def11 sex $head_char $hh_char

mi predict ln_pcexpae_def11_hat using miest, storecompleted

mi xeq: gen pcexpae_def11_hat=exp(ln_pcexpae_def11_hat)
mi xeq: gen poverty_hat=(pcexpae_def11_hat<= povline_def11)


dis "HBS2016"
mi estimate: svy: mean poverty_hat

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

// 1. impute explanatory variables in LFS by year
// 2. then, use the previously saved model to predict consumptions for each LFS year
// finally, calculate the poverty rate

local years "2016 2015 2014 2013 2012 2011 2009 2008"
foreach i of local years {
// use "Z:\Dropbox\WorldBank_Qi\St Lucia and Grenada Multi-year\St Lucia\Processed_Qi\lca_2008_2016.dta",clear 
use "https://www.dropbox.com/s/5d3cscf5y82409y/lca_2008_2016.dta?dl=1", clear
//  use "/Users/yd/Dropbox/WorldBank_Qi/St Lucia and Grenada Multi-year/St Lucia/Processed_Qi/lca_2008_2016.dta", clear
quietly{
keep if year==`i'
replace age_range=. if age_range>=15
recode age_range (1/3=1 0_14)(4/5=2 15_24)(6/8=3 25_40)(9/13=4 41_64)(14=5 above65), gen(age_group)

rename maxedu1 edu_group

rename hhsize members
rename age_original age

rename homeown own_home
rename vehic car
rename washer wash_machine
gen telef=(phone==1|cel==1)
rename rooms nex_room 
rename bedrooms n_bedroom

rename wgt weight
gen nweight = weight*members

rename hrs1 total_hrs
destring hhid, replace
gen survey = "LFS"

gen employed 	= (unemploy1==0 & eap1==1 & age>14)
gen unemployed	= (unemploy1==1 & eap1==1 & age>14)
gen not_LF		= (eap1==0 & age>14)

gen 	emp_status	 =1 if 	employed	== 1 
replace emp_status	 =2 if 	unemployed  == 1
replace emp_status	 =3 if  not_LF		== 1
label 	def			emp_status 	1 "employed" 2 "unemployed" 3 "out of LF" 
label 	val			emp_status emp_status

gen member_sq = members*members

gen parish=dist

egen no_dependent	   =total(age_group==1), by(hhid)

gen occupation=1 if selfemp==1
replace occupation=2 if employer==1
replace occupation=3 if employee==1

label define occupation 1 self_employed 2 employer 3 employee
label values occupation occupation

egen married=total(relation==2), by(hhid)
replace married =1 if married>0

destring ed, replace

replace sector=10 if sector==4
drop if parish==0 | parish==.

global head_char "sex relation hhid married age_group edu_group emp_status sector occupation unemployed emp_status"
global hh_char "no_dependent urban parish members member_sq own_home wash_machine fridge telef n_bedroom car computer"

keep ed hhead nweight weight survey year $head_char $hh_char 


gen povline 	 	=	6443 		
gen povline_def11	=	6067.426	

global char_cont "n_bedroom"
global char_bi "married own_home wash_machine fridge car computer"
global char_cat_uno "sector emp_status occupation"
global char_cat_o "edu_group"
tab age_group, gen(age_group_)

// impute missing values for all necessary variables except ln_percpae_def11

mi set mlong
mi register imputed  $char_cont $char_bi $char_cat_uno $char_cat_o
mi impute chained (regress) $char_cont (logit) $char_bi (mlogit) $char_cat_uno (ologit) $char_cat_o = sex [pw=weight], augment add(10) rseed(1234) force noisily 

replace sector=0	if unemployed ==1
replace sector=100	if emp_status ==3 //out of LF

replace occupation = 0		if unemployed == 1 //unemployed
replace occupation = 100	if emp_status ==	 3 //out of LF

tab edu_group, gen(edu_group_)
mi passive: egen no_no_school	   =total(edu_group_1==1), by(hhid)
mi passive: egen no_primary 	   =total(edu_group_2==1), by(hhid)
mi passive: egen no_secondary      =total(edu_group_3==1), by(hhid)
mi passive: egen no_tertiary       =total(edu_group_4==1), by(hhid)

tab occupation, gen(occupation_)
mi passive: egen no_self_employed=total(occupation_1==1), by(hhid)
mi passive: egen no_employer     =total(occupation_2==1), by(hhid)
mi passive: egen no_employee     =total(occupation_3==1), by(hhid)

keep if hhead==1

tab sector, gen(sector_)
tab parish, gen(parish_)
tab emp_status, gen(emp_status_)

mi svyset 	ed	[pw=nweight], strata(parish)
mi convert flong, clear
mi predict ln_pcexpae_def11_hat using miest, storecompleted


mi xeq: gen pcexpae_def11_hat=exp(ln_pcexpae_def11_hat)
mi xeq: gen poverty_hat=(pcexpae_def11_hat<= povline_def11)
}
dis `i'
mi estimate: svy: mean poverty_hat
}
