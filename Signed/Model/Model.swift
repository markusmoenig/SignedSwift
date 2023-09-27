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
    
    /// Show Context
    let showContext                         = PassthroughSubject<(Point?, Shape?, Float, Float), Never>()
    
    /// Project needs to rebuild
    let rebuild                             = PassthroughSubject<Void, Never>()
    
    //
    
    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
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
    
    /// Build the project, i.e. model the project state
    func build() {
        
        var id : Float = 0.01
        pointMap = [:]
        
        modeler?.clear()
        if let project = currProject {
            for p in project.points?.allObjects as! [Point] {
                
                if project.showPoints {
                    let cmd = SignedCommand("Sphere", role: .GeometryAndMaterial, action: .Add, primitive: .Sphere)
                    
                    if let data = cmd.dataGroups.getGroup("Transform") {
                        data.set("position", float3(p.x, p.y, p.z))
                    }
                    
                    if let data = cmd.dataGroups.getGroup("Geometry") {
                        data.set("radius", 1.0 / 50.0)
                    }
                    
                    cmd.material.data.set("color", float3(p.red, p.green, p.blue))
                    cmd.material.data.set("roughness", 0.5)
                    //cmd.material.albedo = float3(p.red, p.green, p.blue)
                    modeler?.executeCommand(cmd: cmd, id: id)
                    pointMap[id] = p.id
                }
                
                if project.showShapes {
                    for shape in p.shapes?.allObjects as! [Shape] {
                        
                        var primitive : SignedCommand.Primitive = .Sphere
                        if let name = shape.shapeName {
                            if name == "Box" {
                                primitive = .Box
                            }
                        }
                        
                        var action : SignedCommand.Action = .Add
                        if let name = shape.blendModeName {
                            if name == "Subtract" {
                                print("jere")
                                action = .Subtract
                            }
                        }
                        
                        let cmd = SignedCommand("Sphere", role: .GeometryAndMaterial, action: action, primitive: primitive)
                        
                        if let data = cmd.dataGroups.getGroup("Transform") {
                            data.set("position", float3(p.x, p.y, p.z))
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
                        
                        cmd.material.data.set("color", float3(shape.material!.red, shape.material!.green, shape.material!.blue))
                        
                        cmd.material.data.set("roughness", shape.material!.roughness)
                        cmd.material.data.set("metallic", shape.material!.metallic)
                        
                        if let data = cmd.dataGroups.getGroup("Modifier") {
                            data.set("noise", shape.noise)
                        }
                        modeler?.executeCommand(cmd: cmd, id: id)
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
