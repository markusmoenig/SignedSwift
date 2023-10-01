//
//  ShapeView.swift
//  Signed
//
//  Created by Markus Moenig on 24/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct ShapeView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let model                               : Model
    var project                             : Project
    let shape                               : Shape
        
    let nameWidth                           : CGFloat = 70
    
    @State var shapeName                    : String
    @State var blendModeName                : String

    @State var smoothingValue               : Float = 0
    @State var radiusValue                  : Float = 0
    
    @State var sizeXValue                   : Float = 0
    @State var sizeXValueText               : String = ""

    @State var sizeYValue                   : Float = 0
    @State var sizeYValueText               : String = ""
    
    @State var sizeZValue                   : Float = 0
    @State var sizeZValueText               : String = ""
    
    @State private var materialPopover      : Bool = false

    @State var noiseValue                   : Float = 0
    @State var onionValue                   : Float = 0

    @State var cutOffValue                  : Float = 0
    @State var cutOffValueText              : String = ""
    
    @State var materialId                   : UUID? = nil
    
    init(model: Model, project: Project, shape: Shape) {
        
        self.model = model
        self.project = project
        self.shape = shape
                
        if shape.shapeName == nil {
            shape.shapeName = "Sphere"
        }
        self._shapeName = State(initialValue: shape.shapeName!)
        
        if shape.blendModeName == nil {
            shape.blendModeName = "Add"
            shape.smoothing = 0.0
        }
        self._blendModeName = State(initialValue: shape.blendModeName!)
        
        if shape.shapeName == "Sphere" {
            self._radiusValue = State(initialValue: shape.radius)
        } else
        if shape.shapeName == "Box" {
            self._sizeXValue = State(initialValue: shape.sizeX)
            self._sizeXValueText = State(initialValue: String(format: "%.03f", shape.sizeX))
            
            self._sizeYValue = State(initialValue: shape.sizeY)
            self._sizeYValueText = State(initialValue: String(format: "%.03f", shape.sizeY))
            
            self._sizeZValue = State(initialValue: shape.sizeZ)
            self._sizeZValueText = State(initialValue: String(format: "%.03f", shape.sizeZ))
        }
        
        self._smoothingValue = State(initialValue: shape.smoothing)
        
        self._noiseValue = State(initialValue: shape.noise)
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(shape.name!)
                .font(.system(size: 18))
                .onTapGesture(perform: {
                })
            
            Menu(content: {
                Button(action: {
                    shapeName = "Sphere"
                    shape.shapeName = "Sphere"
                    save("Change shape")
                    model.build()
                }) {
                    Text("Sphere")
                }
                Button(action: {
                    shapeName = "Box"
                    shape.shapeName = "Box"
                    save("Change shape")
                    model.build()
                }) {
                    Text("Box")
                }
                Button(action: {
                    shapeName = "Cylinder"
                    shape.shapeName = "Cylinder"
                    save("Change shape")
                    model.build()
                }) {
                    Text("Cylinder")
                }
            }, label: {
                Text(shapeName)
            })
            
            if shapeName == "Sphere" {
                FloatView(name: "Radius", nameWidth: nameWidth, value: $radiusValue, range: float2(0.001, 0.5))
                    .onChange(of: radiusValue, perform: { value in
                        shape.radius = value
                        model.build()
                        save("Radius")
                    })
            } else
            if shapeName == "Box" {
                HStack {
                    Text("Size X")
                    
                    Slider(value: Binding<Float>(get: {sizeXValue}, set: { v in
                        sizeXValue = v
                        sizeXValueText = String(format: "%.03f", v)
                        shape.sizeX = v
                        model.build()
                        save("Size")
                    }), in: Float(0.001)...Float(1.5))
                    
                    Text(sizeXValueText)
                        .frame(maxWidth: 40)
                }
                HStack {
                    Text("Size Y")
                    
                    Slider(value: Binding<Float>(get: {sizeYValue}, set: { v in
                        sizeYValue = v
                        sizeYValueText = String(format: "%.03f", v)
                        shape.sizeY = v
                        model.build()
                        save("Size")
                    }), in: Float(0.001)...Float(1.5))
                    
                    Text(sizeYValueText)
                        .frame(maxWidth: 40)
                }
                HStack {
                    Text("Size Z")
                    
                    Slider(value: Binding<Float>(get: {sizeZValue}, set: { v in
                        sizeZValue = v
                        sizeZValueText = String(format: "%.03f", v)
                        shape.sizeZ = v
                        model.build()
                        save("Size")
                    }), in: Float(0.001)...Float(1.5))
                    
                    Text(sizeZValueText)
                        .frame(maxWidth: 40)
                }
            }
            
            Menu(content: {
                Button(action: {
                    blendModeName = "Add"
                    shape.blendModeName = "Add"
                    save("Change shape")
                    model.build()
                }) {
                    Text("Add")
                }
                Button(action: {
                    blendModeName = "Subtract"
                    shape.blendModeName = "Subtract"
                    save("Change shape")
                    model.build()
                }) {
                    Text("Subtract")
                }
            }, label: {
                Text("Blend: " + blendModeName)
            })
            
            FloatView(name: "Smoothing", nameWidth: nameWidth, value: $smoothingValue, range: float2(0.0, 0.5))
                .onChange(of: smoothingValue, perform: { value in
                    shape.smoothing = value
                    model.build()
                    save("Smoothing")
                })
            
            Button(action: {
                materialPopover = true
            }) {
                Text("Material")
            }
            .popover(isPresented: self.$materialPopover,
                     arrowEdge: .leading
            ) {
                VStack(alignment: .leading) {
                    MaterialPicker(model: model, id: $materialId)
                }
            }
            .onChange(of: materialId, perform: { value in
                if materialId != shape.material {
                    shape.material = materialId
                    model.build()
                    save("material")
                }
            })
                
            //Text("Modifier")
            //.bold()
            FloatView(name: "Noise", nameWidth: nameWidth, value: $noiseValue, range: float2(0.0, 2.0))
                .onChange(of: noiseValue, perform: { value in
                    shape.noise = value
                    model.build()
                    save("Noise")
                })
            
            FloatView(name: "Onion", nameWidth: nameWidth, value: $onionValue, range: float2(0.0, 0.1))
                .onChange(of: onionValue, perform: { value in
                    shape.onion = value
                    model.build()
                    save("Onion")
                })
            
            HStack {
                Text("CutOffX")
                
                Slider(value: Binding<Float>(get: {cutOffValue}, set: { v in
                    cutOffValue = v
                    cutOffValueText = String(format: "%.02f", v)
                    shape.cutOffX = v
                    model.build()
                    save("CutOffX")
                }), in: Float(0.001)...Float(1.0))
                
                Text(cutOffValueText)
                    .frame(maxWidth: 40)
            }
        }
    }
    
    /// Save the context
    func save(_ text: String) {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print(text, nsError)
        }
    }
}
        
