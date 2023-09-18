//
//  Model.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import Foundation
import Combine

class Model: NSObject, ObservableObject {
 
    enum SignedProgress {
        case none, modelling, rendering
    }
    
    enum RenderType {
        case pbr, bsdf
    }
    
    /// Reference to the current renderView
    var renderView                          : SMTKView!
    
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
    var renderName                          = "renderPBR"
    var renderType                          : RenderType = .bsdf
    
    /// Current renderer
    var currentRenderName                   = "renderPBR"
    
    /// The project itself
    var project                             : SignedProject
    
    /// Update UIs
    let updateUI                            = PassthroughSubject<Void, Never>()
    
    /// Send when the current  progress changed
    let progressChanged                     = PassthroughSubject<Void, Never>()
    
    /// Send when modelling is starting
    let modellingStarted                    = PassthroughSubject<Void, Never>()
    /// Send when modelling is finished
    let modellingEnded                      = PassthroughSubject<Void, Never>()
    
    //
    
    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
    override init() {
        project = SignedProject()
        super.init()
    }
    
    func setProject(_ project: SignedProject) {
        self.project = project
    }
    
    /// Sets the renderer
    func setRenderView(_ renderView: SMTKView)
    {
        self.renderView = renderView
        if renderer == nil {
            renderer = RenderPipeline(self)
            
//            self.renderer?.iconQueue += shapes
//            self.renderer?.installNextShapeIconCmd(shapes.first)
        }
        renderView.renderer = renderer
        
        let cmd = SignedCommand("Sphere", role: .GeometryAndMaterial, action: .Add, primitive: .Sphere, data: ["Geometry": SignedData([SignedDataEntity("radius", Float(0.49), float2(0, 5), .Slider, .None, "Radius of the sphere.")])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5)))

//        let cmd = SignedCommand("Box", role: .GeometryAndMaterial, action: .Add, primitive: .Box, data: ["Geometry": SignedData([SignedDataEntity("size", float3(0.065,0.065,0.065) * 7, float2(0,10), .Slider, .None, "Size of the box."), SignedDataEntity("rounding", Float(0.01), float2(0,1), .Slider, .None, "Rounding of the box.")])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5)))
        modeler?.executeCommand(cmd)
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
