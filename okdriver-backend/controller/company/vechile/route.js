const {addVehicle, loginVehicle}=require("./addVechileDetailsController")
const {getAllVehicles}=require("./allVechileDetailsController")
const {deleteVehicle}=require("./deleteVechileDetailsController")
const {updateVehicle}=require("./updateVechileDetails.controller")
const {updateLiveLocation, getLatestLocation, getLocationHistory}=require("./liveLocationController")


module.exports = {
  addVehicle,
  loginVehicle,
  getAllVehicles,
  deleteVehicle,
  updateVehicle,
  updateLiveLocation,
  getLatestLocation,
  getLocationHistory,
};
