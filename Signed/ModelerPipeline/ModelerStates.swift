//
//  ModelerStates.swift
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

import MetalKit

class ModelerStates {
    
    var defaultLibrary          : MTLLibrary!
    var computeStates           : [String: MTLComputePipelineState] = [:]

    var device                  : MTLDevice
    
    init(_ device: MTLDevice)
    {
        self.device = device
        defaultLibrary = device.makeDefaultLibrary()
        
        computeStates["modelerCmd"] = createComputeState(name: "modelerCmd")
        computeStates["modelerHitScene"] = createComputeState(name: "modelerHitScene")
        computeStates["modelerClear"] = createComputeState(name: "modelerClear")
        computeStates["modelerHitPointCloud"] = createComputeState(name: "modelerHitPointCloud")
        computeStates["modelerMakeCGIImage"] = createComputeState(name: "modelerMakeCGIImage")
    }
    
    /// Creates a compute state from an optional library and the function name
    func createComputeState( library: MTLLibrary? = nil, name: String ) -> MTLComputePipelineState?
    {
        let function : MTLFunction?
            
        if library != nil {
            function = library!.makeFunction( name: name )
        } else {
            function = defaultLibrary!.makeFunction( name: name )
        }
        
        var computePipelineState : MTLComputePipelineState?
        
        if function == nil {
            return nil
        }
        
        do {
            computePipelineState = try device.makeComputePipelineState( function: function! )
        } catch {
            print( "computePipelineState failed" )
            return nil
        }

        return computePipelineState
    }
    
    func getComputeState(stateName: String) -> MTLComputePipelineState?
    {
        return computeStates[stateName]
    }
}
