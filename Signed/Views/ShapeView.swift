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
    let point                               : Point
    let shape                               : Shape
    
    @State var shapeName                    : String
    @State var blendModeName                : String

    @State var smoothingValue               : Float = 0
    @State var smoothingValueText           : String = ""
    
    @State var radiusValue                  : Float = 0
    @State var radiusValueText              : String = ""
    
    @State var sizeXValue                   : Float = 0
    @State var sizeXValueText               : String = ""

    @State var sizeYValue                   : Float = 0
    @State var sizeYValueText               : String = ""
    
    @State var sizeZValue                   : Float = 0
    @State var sizeZValueText               : String = ""
    
    @State private var materialPopover      : Bool = false

    @State var noiseValue                   : Float = 0
    @State var noiseValueText               : String = ""
    
    init(model: Model, project: Project, point: Point, shape: Shape) {
        
        self.model = model
        self.project = project
        self.point = point
        self.shape = shape
        
        if shape.shapeName == nil {
            shape.shapeName = "Sphere"
        }
        shapeName = shape.shapeName!
        
        if shape.blendModeName == nil {
            shape.blendModeName = "Add"
            shape.smoothing = 0.0
        }
        blendModeName = shape.blendModeName!
        
        if shape.shapeName == "Sphere" {
            self._radiusValue = State(initialValue: shape.radius)
            self._radiusValueText = State(initialValue: String(format: "%.03f", shape.radius))
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
        self._smoothingValueText = State(initialValue: String(format: "%.03f", shape.smoothing))
        
        self._noiseValue = State(initialValue: shape.noise)
        self._noiseValueText = State(initialValue: String(format: "%.03f", shape.noise))
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
            }, label: {
                Text(shapeName)
            })
            
            if shapeName == "Sphere" {
                HStack {
                    Text("Radius")
                    
                    Slider(value: Binding<Float>(get: {radiusValue}, set: { v in
                        radiusValue = v
                        radiusValueText = String(format: "%.03f", v)
                        shape.radius = v
                        model.build()
                        save("Radius")
                    }), in: Float(0.001)...Float(0.5))
                    
                    Text(radiusValueText)
                        .frame(maxWidth: 40)
                }
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
            
            //if shapeName == "Sphere" {
                HStack {
                    Text("Smoothing")
                    
                    Slider(value: Binding<Float>(get: {smoothingValue}, set: { v in
                        smoothingValue = v
                        smoothingValueText = String(format: "%.03f", v)
                        shape.smoothing = v
                        model.build()
                        save("Smoothing")
                    }), in: Float(0.0)...Float(0.5))
                    
                    Text(smoothingValueText)
                        .frame(maxWidth: 40)
                }
            //}
            
            Button(action: {
                materialPopover = true
            }) {
                Text("Material")
            }
            .popover(isPresented: self.$materialPopover,
                     arrowEdge: .leading
            ) {
                VStack(alignment: .leading) {
                    MaterialView(model: model, project: project, point: point, shape: shape)
                }.padding()
            }
                
            //Text("Modifier")
            //.bold()
            HStack {
                Text("Noise")
                
                Slider(value: Binding<Float>(get: {noiseValue}, set: { v in
                    noiseValue = v
                    noiseValueText = String(format: "%.02f", v)
                    shape.noise = v
                    model.build()
                    save("Noise")
                }), in: Float(0.001)...Float(2.0))
                
                Text(noiseValueText)
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
        
