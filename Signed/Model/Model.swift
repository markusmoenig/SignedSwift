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
    
    /// The rpoject changed
    let projectChanged                      = PassthroughSubject<Project?, Never>()
    
    /// Current point changed
    let pointChanged                        = PassthroughSubject<Point?, Never>()
    
    /// Current line changed
    let lineChanged                         = PassthroughSubject<Line?, Never>()
    
    /// Show Context
    let showContext                         = PassthroughSubject<(Point?, Shape?, Float, Float), Never>()
    
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
    
    /// Build the project, i.e. model the project state
    func build() {
        
        var id : Float = 0.01
        if renderIsMain {
            pointMap = [:]
        }
        
        print("build")
        
        func createCmd(shape: Shape, position: float3, rotation: float3 = float3(0,0,0)) -> SignedCommand {
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
                data.set("radius", shape.radius)
                data.set("size", float3(shape.sizeX, shape.sizeY, shape.sizeZ))
            }

            if let data = cmd.dataGroups.getGroup("Boolean") {
                if let blendModeName = shape.blendModeName {
                    data.set("mode", blendModeName)
                    data.set("smoothing", shape.smoothing)
                }
            }
            
//            cmd.material.data.set("color", float3(shape.material!.red, shape.material!.green, shape.material!.blue))
//            
//            cmd.material.data.set("subsurface", shape.material!.subsurface)
//            cmd.material.data.set("metallic", shape.material!.metallic)
//            cmd.material.data.set("specular", shape.material!.specular)
//            cmd.material.data.set("specularTint", shape.material!.specularTint)
//            cmd.material.data.set("roughness", shape.material!.roughness)
//            cmd.material.data.set("anisotropic", shape.material!.anisotropic)
//            cmd.material.data.set("sheen", shape.material!.sheen)
//            cmd.material.data.set("sheenTint", shape.material!.sheenTint)
//            cmd.material.data.set("clearcoat", shape.material!.clearcoat)
//            cmd.material.data.set("clearcoatGloss", shape.material!.clearcoatGloss)
//            cmd.material.data.set("transmission", shape.material!.transmission)
//            cmd.material.data.set("ior", shape.material!.ior)
//            cmd.material.data.set("emission", float3(repeating: shape.material!.emission))

            if let data = cmd.dataGroups.getGroup("Modifier") {
                data.set("noise", shape.noise)
                data.set("onion", shape.onion)
                data.set("max", float3(shape.cutOffX, 10.0, 10.0))
            }

            return cmd
        }
                
        modeler?.clear()
        if let project = currProject {
            for p in project.points?.allObjects as! [Point] {
                
                if project.showPoints {
//                    let cmd = SignedCommand("Sphere", role: .GeometryAndMaterial, action: .Add, primitive: .Sphere)
//                    
//                    if let data = cmd.dataGroups.getGroup("Transform") {
//                        data.set("position", float3(p.x, p.y, p.z))
//                    }
//                    
//                    if let data = cmd.dataGroups.getGroup("Geometry") {
//                        data.set("radius", 1.0 / 50.0)
//                    }
//                    
//                    cmd.material.data.set("color", float3(p.red, p.green, p.blue))
//                    cmd.material.data.set("roughness", 0.5)
//                    //cmd.material.albedo = float3(p.red, p.green, p.blue)
//                    modeler?.executeCommand(cmd: cmd, id: id)
                    if renderIsMain {
                        pointMap[id] = p.id
                    }
                }
                
                if project.showShapes {
                    for shape in p.shapes?.allObjects as! [Shape] {
                        let cmd = createCmd(shape: shape, position: float3(p.x, p.y, p.z))
                        modeler?.executeCommand(cmd: cmd, id: id)
                    }
                }
                
                id += 0.01
            }
            
            for l in project.lines?.allObjects as! [Line] {

                if renderIsMain {
                    pointMap[id] = l.id
                }

                let from = getPoint(l.startPoint)
                let to = getPoint(l.endPoint)
                
                func getAngle(_ line: [float2]) -> Float {
                    let start = line[0]
                    let end = line[1]
                    
                    let delta = end - start
                    return atan2(delta.y, delta.x).radiansToDegrees
                }
                
                if let from = from {
                    if let to = to {
                        
                        let f = float3(from.x, from.y, from.z)
                        let t = float3(to.x, to.y, to.z)
                        
                        let middle = (f + t) / 2
                        let rotation = float3(
                            f.x < t.x ? getAngle([float2(f.y, f.z), float2(t.y, t.z)]) :  getAngle([float2(t.y, t.z), float2(f.y, f.z)]),
                            f.y < t.y ? getAngle([float2(f.x, f.z), float2(t.x, t.z)]) : getAngle([float2(t.x, t.z), float2(f.x, f.z)]),
                            f.z < t.z ? getAngle([float2(f.x, f.y), float2(t.x, t.y)]) : getAngle([float2(t.x, t.y), float2(f.x, f.y)])
                        )
                        
                        for shape in l.shapes?.allObjects as! [Shape] {
                            
                            let cmd = createCmd(shape: shape, position: middle, rotation: rotation)
                            modeler?.executeCommand(cmd: cmd, id: id)
                        }
                    }
                }
                id += 0.01
            }
        }
        
        renderer?.restart()
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
