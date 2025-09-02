const {addVehicle}=require("./addVechileDetailsController")
const {getAllVehicles}=require("./allVechileDetailsController")
const {deleteVehicle}=require("./deleteVechileDetailsController")
const {updateVehicle}=require("./updateVechileDetails.controller")


module.exports = {
  addVehicle,
  getAllVehicles,
  deleteVehicle,
  updateVehicle,
};
