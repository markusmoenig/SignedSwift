//
//  Model.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import Foundation
import Combine
import SwiftUI

class Model: NSObject, ObservableObject {
 
    enum SignedProgress {
        case none, modelling, rendering
    }
    
    enum RenderType {
        case pbr, bsdf
    }
    
    /// Reference to the current renderView
    var renderView                          : SMTKView!
    var pointsView                          : SMTKView!

    /// Reference to the renderer
    var renderer                            : RenderPipeline? = nil
    var modeler                             : ModelerPipeline? = nil
    
    /// The modeling progress
    ///
    var progress                            : SignedProgress = .none
    
    var progressValue                       : Double = 0
    var progressCurrent                     : Int32 = 0
    var progressTotal                       : Int32 = 0
    
    /// renderName (User setting)
    var renderName                          = "renderBSDF"
    var renderType                          : RenderType = .bsdf
    
    /// Current renderer
    var currentRenderName                   = "renderPBR"
    
    /// The project itself
    var project                             : SignedProject
        
    var currProject                         : Project? = nil
    var currMaterial                        : Material? = nil

    var currPoint                           : Point? = nil
    var currLine                            : Line? = nil

    var pointEditAxisMode                   : Int32 = POINT_AXIS_XZ

    /// Send when the camera mode changed
    let cameraModeChanged                   = PassthroughSubject<ModelerKit.Content, Never>()
    
    /// Update UIs
    let updateUI                            = PassthroughSubject<Void, Never>()
    
    /// Send when the current  progress changed
    let progressChanged                     = PassthroughSubject<Void, Never>()
    
    /// Send when modelling is starting
    let modellingStarted                    = PassthroughSubject<Void, Never>()
    /// Send when modelling is finished
    let modellingEnded                      = PassthroughSubject<Void, Never>()
    
    /// The project changed
    let projectChanged                      = PassthroughSubject<Project?, Never>()
    
    /// The project changed
    let materialChanged                      = PassthroughSubject<Material?, Never>()
    
    /// Current point changed
    let pointChanged                        = PassthroughSubject<Point?, Never>()
    
    /// Current line changed
    let lineChanged                         = PassthroughSubject<Line?, Never>()

    /// Current shape changed
    let shapeChanged                        = PassthroughSubject<Shape?, Never>()

    /// Project needs to rebuild
    let rebuild                             = PassthroughSubject<Void, Never>()
    
    //
    
    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    var renderIsMain                        : Bool = true
    
    /// Maps point ids in the model texture to the points uuids
    var pointMap                            : [Float: UUID] = [:]
    
    override init() {
        project = SignedProject()
        super.init()
    }
    
    func setProject(_ project: SignedProject) {
        self.project = project
    }
    
    /// Sets the renderView
    func setRenderView(_ renderView: SMTKView)
    {
        self.renderView = renderView
        if renderer == nil {
            renderer = RenderPipeline(self)
            
//            self.renderer?.iconQueue += shapes
//            self.renderer?.installNextShapeIconCmd(shapes.first)
        }
        renderView.renderer = renderer
                
//        let cmd = SignedCommand("Sphere", role: .GeometryAndMaterial, action: .Add, primitive: .Sphere, data: ["Geometry": SignedData([SignedDataEntity("radius", Float(0.49), float2(0, 5), .Slider, .None, "Radius of the sphere.")])], material: SignedMaterial(albedo: float3(1.5,0.5,0.5), metallic: 1.0))
//        modeler?.executeCommand(cmd: cmd, id: 0)

//        let cmd1 = SignedCommand("Box", role: .GeometryAndMaterial, action: .Add, primitive: .Box, data: ["Geometry": SignedData([SignedDataEntity("size", float3(0.99, 0.99, 0.99), float2(0,10), .Slider, .None, "Size of the box."), SignedDataEntity("rounding", Float(0.01), float2(0,1), .Slider, .None, "Rounding of the box.")])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5), metallic: 1.0))
//        modeler?.executeCommand(cmd1)
    }
    
    /// Returns the point of the given id
    func getPoint(_ id: UUID?) -> Point? {
        if id == nil { return nil }
        
        if let project = currProject {
            for p in project.points?.allObjects as! [Point] {
                if p.id == id {
                    return p
                }
            }
        }
        
        return nil
    }
    
    /// Returns the line of the given id
    func getLine(_ id: UUID?) -> Line? {
        if id == nil { return nil }
        
        if let project = currProject {
            for l in project.lines?.allObjects as! [Line] {
                if l.id == id {
                    return l
                }
            }
        }
        
        return nil
    }
    
    /// Returns the material of the given id
    func getMaterial(_ id: UUID?) -> Material? {
        if id == nil { return nil }
        
        let request = Material.fetchRequest()
        
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let materials = try! managedObjectContext.fetch(request)
        
        for material in materials {
            if material.id == id {
                return material
            }
        }

        return nil
    }
    
    /// Build the project, i.e. model the project state
    func build() {
        
        DispatchQueue.main.async {
            
            var id : Float = 0.01
            self.pointMap = [:]
            
            print("build")
            
            func setMaterial(cmd: SignedCommand, material: Material) {
                cmd.material.data.set("color", float3(material.red, material.green, material.blue))
                
                cmd.material.data.set("subsurface", material.subsurface)
                cmd.material.data.set("metallic", material.metallic)
                cmd.material.data.set("specular", material.specular)
                cmd.material.data.set("specularTint", material.specularTint)
                cmd.material.data.set("roughness", material.roughness)
                cmd.material.data.set("anisotropic", material.anisotropic)
                cmd.material.data.set("sheen", material.sheen)
                cmd.material.data.set("sheenTint", material.sheenTint)
                cmd.material.data.set("clearcoat", material.clearcoat)
                cmd.material.data.set("clearcoatGloss", material.clearcoatGloss)
                cmd.material.data.set("transmission", material.transmission)
                cmd.material.data.set("ior", material.ior)
                cmd.material.data.set("emission", float3(repeating: material.emission))
            }
            
            func createCmd(shape: Shape, position: float3, rotation: float3 = float3(0,0,0), length: Float? = nil) -> SignedCommand {
                var primitive : SignedCommand.Primitive = .Sphere
                if let name = shape.shapeName {
                    if name == "Box" {
                        primitive = .Box
                    }
                    if name == "Cylinder" {
                        primitive = .Cylinder
                    }
                }
                
                var action : SignedCommand.Action = .Add
                if let name = shape.blendModeName {
                    if name == "Subtract" {
                        action = .Subtract
                    }
                }
                
                let cmd = SignedCommand("Sphere", role: .GeometryAndMaterial, action: action, primitive: primitive)
                
                if let data = cmd.dataGroups.getGroup("Transform") {
                    data.set("position", position)
                    data.set("rotation", rotation)
                    //data.set("pivot", position)
                }
                
                if let data = cmd.dataGroups.getGroup("Geometry") {
                    if let length = length {
                        data.set("radius", shape.radius)
                        data.set("size", float3(length, shape.sizeY, shape.sizeZ))
                    } else {
                        data.set("radius", shape.radius)
                        if primitive == .Sphere {
                            data.set("size", float3(shape.radius, shape.sizeY, shape.sizeZ))
                        } else {
                            data.set("size", float3(shape.sizeX, shape.sizeY, shape.sizeZ))
                        }
                        
                    }
                    data.set("rounding", shape.rounding)
                }
                
                if let data = cmd.dataGroups.getGroup("Boolean") {
                    if let blendModeName = shape.blendModeName {
                        data.set("mode", blendModeName)
                        data.set("smoothing", shape.smoothing)
                    }
                }
                
                if let material = self.getMaterial(shape.material) {
                    setMaterial(cmd: cmd, material: material)
                }
                
                if let data = cmd.dataGroups.getGroup("Modifier") {
                    data.set("noise", shape.noise)
                    data.set("onion", shape.onion)
                    data.set("max", float3(shape.cutOffMax, shape.cutOffMin, 10.0))
                }
                
                return cmd
            }
            
            self.modeler?.clear()
            if let project = self.currProject {
                for p in project.points?.allObjects as! [Point] {
                    
                    self.pointMap[id] = p.id

                    for shape in p.shapes?.allObjects as! [Shape] {
                        let cmd = createCmd(shape: shape, position: float3(p.x, p.y, p.z))
                        self.modeler?.executeCommand(cmd: cmd, id: id)
                    }
                    
                    id += 0.01
                }
                
                for l in project.lines?.allObjects as! [Line] {
                    
                    self.pointMap[id] = l.id
                    
                    let from = self.getPoint(l.startPoint)
                    let to = self.getPoint(l.endPoint)
                    
                    if let from = from {
                        if let to = to {
                            
                            let f = float3(from.x, from.y, from.z)
                            let t = float3(to.x, to.y, to.z)
                            
                            let dir = t - f
                            let direction = simd_normalize(dir)

                            // Calculate the rotation matrix
                            func rotationMatrix(from vector: simd_float3) -> simd_float3x3 {
                                let x = simd_normalize(simd_float3(1.0, 0.0, 0.0))
                                let dot = simd_dot(x, vector)
                                
                                if abs(dot - (-1.0)) < 0.000001 {
                                    return simd_float3x3([
                                        simd_float3(0.0, -1.0, 0.0),
                                        simd_float3(0.0, 0.0, -1.0),
                                        simd_float3(-1.0, 0.0, 0.0)
                                    ])
                                }
                                if abs(dot - 1.0) < 0.000001 {
                                    return simd_float3x3([
                                        simd_float3(1.0, 0.0, 0.0),
                                        simd_float3(0.0, 1.0, 0.0),
                                        simd_float3(0.0, 0.0, 1.0)
                                    ])
                                }
                                
                                let axis = simd_cross(x, vector)
                                let angle = acos(dot)
                                let c = cos(angle)
                                let s = sin(angle)
                                let t = 1.0 - c
                                
                                let x_x = t * axis.x * axis.x + c
                                let x_y = t * axis.x * axis.y - s * axis.z
                                let x_z = t * axis.x * axis.z + s * axis.y
                                
                                let y_x = t * axis.x * axis.y + s * axis.z
                                let y_y = t * axis.y * axis.y + c
                                let y_z = t * axis.y * axis.z - s * axis.x
                                
                                let z_x = t * axis.x * axis.z - s * axis.y
                                let z_y = t * axis.y * axis.z + s * axis.x
                                let z_z = t * axis.z * axis.z + c
                                
                                return simd_float3x3([
                                    simd_float3(x_x, x_y, x_z),
                                    simd_float3(y_x, y_y, y_z),
                                    simd_float3(z_x, z_y, z_z)
                                ])
                            }
                            
                            // Extract Euler angles from the rotation matrix
                            func rotationMatrixToEulerAngles(_ matrix: simd_float3x3) -> simd_float3 {
                                let sy = sqrt(matrix[0, 0] * matrix[0, 0] + matrix[1, 0] * matrix[1, 0])
                                
                                let singular = sy < 1e-6
                                
                                var x, y, z: Float
                                
                                if !singular {
                                    x = atan2(matrix[2, 1], matrix[2, 2])
                                    y = atan2(-matrix[2, 0], sy)
                                    z = atan2(matrix[1, 0], matrix[0, 0])
                                } else {
                                    x = atan2(-matrix[1, 2], matrix[1, 1])
                                    y = atan2(-matrix[2, 0], sy)
                                    z = 0
                                }
                                
                                return simd_float3(x, y, z)
                            }
                            
                            let rotationMatrix = rotationMatrix(from: direction)
                            var rotation = rotationMatrixToEulerAngles(rotationMatrix)

                            rotation.x = -rotation.x
                            rotation.y = -rotation.y
                            
                            let dx = t.x - f.x
                            let dy = t.y - f.y
                            let dz = t.z - f.z
                            let length = sqrt(dx * dx + dy * dy + dz * dz)
                            
                            for shape in l.shapes?.allObjects as! [Shape] {

                                let offset = shape.lineOffset / 2.0
                                let lineSize = shape.lineSize * length

                                let t = 0.5 - offset
                                //t += lineSize / 2 - offset
                                
                                let position = f + dir * t
                            
                                let cmd = createCmd(shape: shape, position: position, rotation: rotation, length: lineSize)
                                self.modeler?.executeCommand(cmd: cmd, id: id)
                            }
                        }
                    }
                    id += 0.01
                }
            } else
            if let material = self.currMaterial {
                
                let cmd = SignedCommand("Sphere", role: .GeometryAndMaterial, action: .Add, primitive: .Sphere, data: ["Geometry": SignedData([SignedDataEntity("size", float3(0.49 * 2.0, 0.49, 0.49), float2(0, 5), .Slider, .None, "Radius of the sphere.")])])
                
                setMaterial(cmd: cmd, material: material)
                self.modeler?.executeCommand(cmd: cmd, id: 0)
            }
            
            self.renderer?.restart()
        }
    }
    
    /// Sets the pointRender View
    func setPointsView(_ pointsView: SMTKView) {
        self.pointsView = pointsView
    }

    /// Gets the renderType for the given ModelerKit
    func getRenderType(kit: ModelerKit) -> RenderType {
        var type : RenderType = .pbr
        
        type = renderType
        
        return type
    }
    
    /// Get the renderer name for the given ModelerKit
    func getRenderName(kit: ModelerKit) -> String {
        switch getRenderType(kit: kit) {
        case .bsdf:
            return "renderBSDF"
        default:
            return "renderPBR"
        }
    }
}
