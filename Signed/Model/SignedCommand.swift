//
//  SignedCommand.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import Foundation
import CoreGraphics
import SwiftUI

/// This object is the base for everything, if its an geometry object or a material
class SignedCommand : Codable, Hashable {
    
    enum Role: Int32, Codable {
        case GeometryAndMaterial, MaterialOnly
    }
    
    enum Action: Int32, Codable {
        case None, Clear, Add, Subtract
    }
    
    enum Primitive: Int32, Codable {
        case Heightfield, Sphere, Box, Cylinder
    }
    
    enum BlendMode: Int32, Codable {
        case Linear, ValueNoise, Depth
    }
    
    var id              = UUID()
    var name            : String
    
    var role            : Role
    var action          : Action
    var primitive       : Primitive
    
    var blendMode       : BlendMode = .Linear
    var blendOptions    = SignedData([])

    //
    
    var dataGroups      : SignedDataGroups
    var material        : SignedMaterial

    var normal          : float3 = float3()

    var code            : String = ""
    
    /// The materialId for this cmd
    var materialId      : Int = 0
    
    var icon            : CGImage? = nil
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case action
        case primitive
        case dataGroups
        case material
        case normal
        case code
        case materialId
        case blendMode
        case blendOptions
    }
    
    init(_ name: String = "Unnamed", role: Role = .GeometryAndMaterial, action: Action = .Add, primitive: Primitive = .Box, data: [String: SignedData] = [:], material: SignedMaterial = SignedMaterial())
    {
        self.name = name
        self.role = role
        self.action = action
        self.primitive = primitive
        self.material = material

        self.dataGroups = SignedDataGroups(data)

        initDataGroups()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        role = try container.decode(Role.self, forKey: .role)
        action = try container.decode(Action.self, forKey: .action)
        primitive = try container.decode(Primitive.self, forKey: .primitive)

        dataGroups = try container.decode(SignedDataGroups.self, forKey: .dataGroups)
        material = try container.decode(SignedMaterial.self, forKey: .material)

        normal = try container.decode(float3.self, forKey: .normal)

        code = try container.decode(String.self, forKey: .code)
        materialId = try container.decode(Int.self, forKey: .materialId)
        blendMode = try container.decode(BlendMode.self, forKey: .blendMode)
        blendOptions = try container.decode(SignedData.self, forKey: .blendOptions)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(action, forKey: .action)
        try container.encode(primitive, forKey: .primitive)
        try container.encode(dataGroups, forKey: .dataGroups)
        try container.encode(material, forKey: .material)
        try container.encode(normal, forKey: .normal)
        try container.encode(code, forKey: .code)
        try container.encode(materialId, forKey: .materialId)
        try container.encode(blendMode, forKey: .blendMode)
        try container.encode(blendOptions, forKey: .blendOptions)
    }
    
    static func ==(lhs: SignedCommand, rhs: SignedCommand) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Initializes the data groups with default values, or, when already exists, make sure all options are present
    func initDataGroups(fromConstructor: Bool = false) {
            
        addDataGroup(name: "Transform", entities: [
            SignedDataEntity("position", float3(0,0,0), float2(-0.5, 0.5), .Numeric, .None, "The position of the shape relative to it's center."),
            SignedDataEntity("rotation", float3(0,0,0), float2(0, 360), .Slider, .None, "The rotation of the shape."),
            SignedDataEntity("pivot", float3(0,0,0), float2(-0.5, 0.5), .Numeric, .None, "The pivot of the rotation."),
        ])
        
        addDataGroup(name: "Modifier", entities: [
            SignedDataEntity("noise", Float(0), float2(0, 2), .Slider, .None, "Adds spherical noise to the surface of the shape."),
            SignedDataEntity("onion", Float(0), float2(0, 1), .Slider, .None, "If > 0 defines the size of the shell of the shape with an hollow interior."),
            SignedDataEntity("depth", float2(-5, 5), float2(-5, 5)),
            SignedDataEntity("max", float3(10,10,10), float2(0, 10), .Slider),
        ])
        
        addDataGroup(name: "Boolean", entities: [
            SignedDataEntity("mode", "add", .TextField, .None, "Boolean mode, one of **add**, **subtract** or **intersect**. **add** is default."),
            SignedDataEntity("smoothing", Float(0.0), float2(0, 1), .Slider, .None, "Smoothing, the higher the value the smoother the boolean operation gets.")
        ])
        
        addDataGroup(name: "Repetition", entities: [
            SignedDataEntity("distance", Float(0.1), float2(0, 5), .Numeric, .None, "The distance between instances."),
            SignedDataEntity("upperLimit", float3(0,0,0), float2(-1000, 1000), .Numeric, .None, "The amount of repetitions in the positive axis directions."),
            SignedDataEntity("lowerLimit", float3(0,0,0), float2(-1000, 1000), .Numeric, .None, "The amount of repetitions in the negative axis directions."),
        ])
        
        addDataGroup(name: "Geometry", entities: [
        ])
    }
    
    /// Creates or adds the given entities to the new or existing group. This way we can dynamically add new options to existing projects.
    func addDataGroup(name: String, entities: [SignedDataEntity]) {
        let group = dataGroups.getGroup(name)
        if let group = group {
            // If group exists, make sure all entities are present

            for e in entities {
                if group.exists(e.key) == false {
                    group.data.append(e)
                }
            }
        } else {
            // If group does not exist add it
            dataGroups.addGroup(name, SignedData(entities))
        }
    }
    
    /// Creates a copy of itself
    func copy() -> SignedCommand?
    {
        if let data = try? JSONEncoder().encode(self) {
            if let copied = try? JSONDecoder().decode(SignedCommand.self, from: data) {
                copied.id = UUID()
                return copied
            }
        }
        return nil
    }
    
    /// Copies the geometry part of the command
    func copyGeometry(from: SignedCommand) {
        primitive = from.primitive
        
        if let data = try? JSONEncoder().encode(from.dataGroups) {
            if let copied = try? JSONDecoder().decode(SignedDataGroups.self, from: data) {
                self.dataGroups = copied
            }
        }
    }
    
    /// Copies the material part of the command
    func copyMaterial(from: SignedMaterial) {
        
        if let data = try? JSONEncoder().encode(from) {
            if let copied = try? JSONDecoder().decode(SignedMaterial.self, from: data) {
                self.material = copied
            }
        }
    }
    
    /// Returns all data groups
    func allDataGroups() -> [SignedData]
    {
        var groups = dataGroups.flat()
        groups.append(material.data)
        return groups
    }
}

