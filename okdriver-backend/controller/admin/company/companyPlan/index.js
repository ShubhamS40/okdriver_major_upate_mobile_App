const {createCompanyPlan}=require('./planCreationController')
const {deleteCompanyPlan}=require('./planDeletionController')
const {getAllCompanyPlans}=require('./getAllCompanyPlansController')
const {updateCompanyPlan}=require('./updatePlanController')




module.exports={createCompanyPlan,deleteCompanyPlan,getAllCompanyPlans,updateCompanyPlan}