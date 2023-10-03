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
        
#if os(iOS)
    let nameWidth                           : CGFloat = 85
#else
    let nameWidth                           : CGFloat = 70
#endif
    
    @State var shapeName                    : String
    @State var blendModeName                : String

    @State var smoothingValue               : Float = 0
    @State var radiusValue                  : Float = 0
    
    @State var sizeXValue                   : Float = 0
    @State var sizeYValue                   : Float = 0
    @State var sizeZValue                   : Float = 0
    
    @State var roundingValue                : Float = 0

    @State var lineOffsetValue              : Float = 0
    @State var lineSizeValue                : Float = 0

    @State private var materialPopover      : Bool = false

    @State var noiseValue                   : Float = 0
    @State var onionValue                   : Float = 0

    @State var cutOffMaxValue               : Float = 0
    @State var cutOffMinValue               : Float = 0

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
        
        self._radiusValue = State(initialValue: shape.radius)
        self._sizeXValue = State(initialValue: shape.sizeX)
        self._sizeYValue = State(initialValue: shape.sizeY)
        self._sizeZValue = State(initialValue: shape.sizeZ)
        
        self._roundingValue = State(initialValue: shape.rounding)
        
        self._lineOffsetValue = State(initialValue: shape.lineOffset)
        self._lineSizeValue = State(initialValue: shape.lineSize)
        
        self._smoothingValue = State(initialValue: shape.smoothing)
        self._noiseValue = State(initialValue: shape.noise)
        
        self._onionValue = State(initialValue: shape.onion)
        self._cutOffMaxValue = State(initialValue: shape.cutOffMax)
        self._cutOffMinValue = State(initialValue: shape.cutOffMin)
    }
    
    var body: some View {
        
        Text(shape.name!)
            .font(.system(size: 18))
            .onTapGesture(perform: {
            })
        
            TabView {

                VStack(alignment: .leading) {
                    
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
                    
                    
                    if let _ = model.getLine(shape.line) {
                        
                        FloatView(name: "Line Offset", nameWidth: nameWidth, value: $lineOffsetValue, range: float2(-1.0, 1.0))
                            .onChange(of: lineOffsetValue, perform: { value in
                                shape.lineOffset = value
                                model.build()
                                save("Line Offset")
                            })
                        
                        FloatView(name: "Line Size", nameWidth: nameWidth, value: $lineSizeValue, range: float2(0.001, 1.0))
                            .onChange(of: lineSizeValue, perform: { value in
                                shape.lineSize = value
                                model.build()
                                save("Line Size")
                            })
                        
                        if shapeName == "Cylinder" {
                            FloatView(name: "Radius", nameWidth: nameWidth, value: $radiusValue, range: float2(0.001, 0.5))
                                .onChange(of: radiusValue, perform: { value in
                                    shape.radius = value
                                    model.build()
                                    save("Radius")
                                })
                        } else
                        if shapeName == "Box" {
                            
                            FloatView(name: "Thickness", nameWidth: nameWidth, value: $sizeYValue, range: float2(0.001, 1.0))
                                .onChange(of: sizeYValue, perform: { value in
                                    shape.sizeY = value
                                    model.build()
                                    save("SizeY")
                                })
                            
                            FloatView(name: "Depth", nameWidth: nameWidth, value: $sizeZValue, range: float2(0.001, 1.0))
                                .onChange(of: sizeZValue, perform: { value in
                                    shape.sizeZ = value
                                    model.build()
                                    save("SizeZ")
                                })
                            
                            FloatView(name: "Rounding", nameWidth: nameWidth, value: $roundingValue, range: float2(0.001, 0.5))
                                .onChange(of: roundingValue, perform: { value in
                                    shape.rounding = value
                                    model.build()
                                    save("SizeZ")
                                })
                        }
                        
                    } else {
                        
                        // Point Shapes
                        
                        if shapeName == "Sphere" {
                            FloatView(name: "Radius", nameWidth: nameWidth, value: $radiusValue, range: float2(0.001, 0.5))
                                .onChange(of: radiusValue, perform: { value in
                                    shape.radius = value
                                    model.build()
                                    save("Radius")
                                })
                        } else
                        if shapeName == "Box" {
                            FloatView(name: "Width", nameWidth: nameWidth, value: $sizeXValue, range: float2(0.001, 1.0))
                                .onChange(of: sizeXValue, perform: { value in
                                    shape.sizeX = value
                                    model.build()
                                    save("SizeX")
                                })
                            
                            FloatView(name: "Height", nameWidth: nameWidth, value: $sizeYValue, range: float2(0.001, 1.0))
                                .onChange(of: sizeYValue, perform: { value in
                                    shape.sizeY = value
                                    model.build()
                                    save("SizeY")
                                })
                            
                            FloatView(name: "Depth", nameWidth: nameWidth, value: $sizeZValue, range: float2(0.001, 1.0))
                                .onChange(of: sizeZValue, perform: { value in
                                    shape.sizeZ = value
                                    model.build()
                                    save("SizeZ")
                                })
                        }
                    }
                    
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
                    
                    Spacer()
                }
                .tabItem {
                    Label("Geometry", systemImage: "cube")
                }

                VStack(alignment: .leading) {
                    
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
                    
                    Spacer()
                }
                .tabItem {
                    Label("Boolean", systemImage: "circle.dotted.and.circle")
                }

                VStack(alignment: .leading) {
                    FloatView(name: "Noise", nameWidth: nameWidth, value: $noiseValue, range: float2(0.0, 2.0))
                        .onChange(of: noiseValue, perform: { value in
                            shape.noise = value
                            model.build()
                            save("Noise")
                        })
                    
                    FloatView(name: "Shell", nameWidth: nameWidth, value: $onionValue, range: float2(0.0, 0.1))
                        .onChange(of: onionValue, perform: { value in
                            shape.onion = value
                            model.build()
                            save("Onion")
                        })
                    
                    FloatView(name: "Cutoff Max", nameWidth: nameWidth, value: $cutOffMaxValue, range: float2(0.0, 0.5))
                        .onChange(of: cutOffMaxValue, perform: { value in
                            shape.cutOffMax = value
                            model.build()
                            save("Cut Off")
                        })
                    
                    FloatView(name: "Cutoff Min", nameWidth: nameWidth, value: $cutOffMinValue, range: float2(0.0, 0.5))
                        .onChange(of: cutOffMinValue, perform: { value in
                            shape.cutOffMin = value
                            model.build()
                            save("Cut Off")
                        })
                    Spacer()
                }
                .tabItem {
                    Label("Modifier", systemImage: "gearshape")
                }
            }

#if os(iOS)
            .frame(height: 310)
#endif

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
        
