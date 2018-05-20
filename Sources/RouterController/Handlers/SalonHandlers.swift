import Foundation
import Kitura
import PerfectCRUD
import PerfectPostgreSQL
import Classes
import CryptoSwift
import SwiftyJSON

extension Controller{

//************************************************************************************************************************//
    
    func postSalonSignUp(request: RouterRequest, response: RouterResponse, _ : @escaping () -> Void) throws {
        guard let nickName = request.queryParameters["nickName"], nickName != "" else{
            try response.status(.badRequest).end()
            return
        }
        guard let password = request.queryParameters["password"], password != "" else{
            try response.status(.badRequest).end()
            return
        }
        let salonTable = self.dataBase.salonTable
        let salonQuery = salonTable.where(\Salon.nickName == nickName)
        guard try salonQuery.count() == 0 else{
            try response.status(.conflict).end()
            return
        }
        let salt = "SwiftyServer"
        let tokenString = nickName + salt + password
        let token = tokenString.md5()
        let salon = Salon(nickName: nickName, token: token)
        try salonTable.insert(salon)
        try response.status(.OK).send(token).end()
    }
    
//************************************************************************************************************************//
    
    func postSalonSignIn(request: RouterRequest, response: RouterResponse, _ : @escaping () -> Void) throws {
        guard let nickName = request.queryParameters["nickName"], nickName != "" else{
            try response.status(.badRequest).end()
            return
        }
        guard let password = request.queryParameters["password"], password != "" else{
            try response.status(.badRequest).end()
            return
        }
        let salt = "SwiftyServer"
        let tokenString = nickName + salt + password
        let token = tokenString.md5()
        let salonTable = self.dataBase.salonTable
        let salonQuery = salonTable.where(\Salon.token == token)
        guard try salonQuery.count() == 1 else{
            try response.status(.badRequest).end()
            return
        }
        try response.status(.OK).send(token).end()
    }
    
//************************************************************************************************************************//
   
    fileprivate struct SalonInfo: Codable{
        let customName: String
        let phoneNumber: String
        let description: String
        let city: String
        let address: String
    }
    
    func postSalonInfo(request: RouterRequest, response: RouterResponse, _ : @escaping () -> Void) throws {
        guard let token = request.queryParameters["token"], token != "" else{
            try response.status(.badRequest).end()
            return
        }
        let salonTable = self.dataBase.salonTable
        let salonQuery = salonTable.where(\Salon.token == token)
        guard try salonQuery.count() == 1 else{
            try response.status(.badRequest).end()
            return
        }
        guard let body = request.body,
              let json = body.asJSON,
              let salonInfo = try? JSONDecoder().decode(SalonInfo.self, from: JSON(json).rawData())
        else{
            try response.status(.badRequest).end()
            return
        }
        let newSalon = Salon(customName: salonInfo.customName,
                             phoneNumber: salonInfo.phoneNumber,
                             description: salonInfo.description,
                             city: salonInfo.city,
                             address: salonInfo.address)
        try salonQuery.update(newSalon, setKeys: \.customName, \.phoneNumber, \.description, \.city, \.address)
        try response.status(.OK).end()
    }
    
//************************************************************************************************************************//
    
    fileprivate struct ServiceInfo: Codable{
        let name : String
        let description: String
        let priceFrom : String
        let priceTo : String
    }
    
    func postSalonAddService(request: RouterRequest, response: RouterResponse, _ : @escaping () -> Void) throws {
        guard let token = request.queryParameters["token"], token != "" else{
            try response.status(.badRequest).end()
            return
        }
        let salonTable = self.dataBase.salonTable
        let salonQuery = salonTable.where(\Salon.token == token)
        guard let salon = try salonQuery.first() else{
            try response.status(.badRequest).end()
            return
        }
        guard let body = request.body,
            let json = body.asJSON,
            let serviceInfo = try? JSONDecoder().decode(ServiceInfo.self, from: JSON(json).rawData())
        else{
            try response.status(.badRequest).end()
            return
        }
        let newService = Service(salonID: salon.salonID,
                                 serviceID: UUID(),
                                 masters: nil,
                                 name: serviceInfo.name,
                                 description: serviceInfo.description,
                                 priceFrom: serviceInfo.priceFrom,
                                 priceTo: serviceInfo.priceTo)
        let serviceTable = self.dataBase.serviceTable
        try serviceTable.insert(newService)
        try response.status(.OK).end()
    }
    
//************************************************************************************************************************//
    
    fileprivate struct MasterInfo: Codable{
        let name : String
        let schedule: [Day]
    }
    
    func postSalonAddNewMaster(request: RouterRequest, response: RouterResponse, _ : @escaping () -> Void) throws {
        guard let token = request.queryParameters["token"], token != "" else{
            try response.status(.badRequest).end()
            return
        }
        let salonTable = self.dataBase.salonTable
        let salonQuery = salonTable.where(\Salon.token == token)
        guard let salon = try salonQuery.first() else{
            try response.status(.badRequest).end()
            return
        }
        guard let body = request.body,
            let json = body.asJSON,
            let masterInfo = try? JSONDecoder().decode(MasterInfo.self, from: JSON(json).rawData())
        else{
            try response.status(.badRequest).end()
            return
        }
        let newMaster = Master(salonID: salon.salonID,
                               masterID: UUID(),
                               services: nil,
                               name: masterInfo.name,
                               schedule: nil)
        let masterTable = self.dataBase.masterTable
        try masterTable.insert(newMaster)
        let dayTable = self.dataBase.dayTable
        for day in masterInfo.schedule{
            var newDay = day
            newDay.masterID = newMaster.masterID
            try dayTable.insert(newDay)
        }
        try response.status(.OK).end()
    }
    
//************************************************************************************************************************//
    
    func postSalonAddMasterToService(request: RouterRequest, response: RouterResponse, _ : @escaping () -> Void) throws {
        guard let token = request.queryParameters["token"], token != "" else{
            try response.status(.badRequest).end()
            return
        }
        guard let serviceID = request.queryParameters["serviceID"], serviceID != "",
              let serviceUUID = UUID(uuidString: serviceID)
        else{
            try response.status(.badRequest).end()
            return
        }
        guard let masterID = request.queryParameters["masterID"], masterID != "",
              let masterUUID = UUID(uuidString: masterID)
        else{
            try response.status(.badRequest).end()
            return
        }
        let salonTable = self.dataBase.salonTable
        let salonQuery = salonTable.where(\Salon.token == token)
        guard let salon = try salonQuery.first() else{
            try response.status(.badRequest).end()
            return
        }
        let serviceToMasterTable = self.dataBase.serviceToMasterTable
        let checkQuery = serviceToMasterTable.where(\ServiceToMaster.masterID == masterUUID && \ServiceToMaster.serviceID == serviceUUID)
        guard try checkQuery.count() == 0 else{
            try response.status(.badRequest).end()
            return
        }
        try serviceToMasterTable.insert(ServiceToMaster(salonID: salon.salonID, serviceID: serviceUUID, masterID: masterUUID))
        try response.status(.OK).end()
    }
    
//************************************************************************************************************************//
        
    func test(request: RouterRequest, response: RouterResponse, _ : @escaping () -> Void) throws {
//        guard let ID = UUID(uuidString: "5eecdc72-b81c-4e58-af06-8b4acd0748c8") else{
//            return
//        }
//        let day = Day(masterID: ID, name: "Monday", isDayOff: true, startTime: "10:00", endTime: "21:00")
//        let master = Master(salonID: UUID(), masterID: ID, services: nil, name: "petya", schedule: nil)
//        let masterTable = self.dataBase.masterTable
//        let dayTable = self.dataBase.dayTable
//        try masterTable.insert(master)
//        try dayTable.insert(day)
//        try response.status(.OK).end()
    }
    
    
}
