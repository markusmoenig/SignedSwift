//
//  ShapeView.swift
//  Signed
//
//  Created by Markus Moenig on 24/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import MobileCoreServices
#endif

struct ShapeView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let model                               : Model
    var project                             : Project
    let point                               : Point
    let shape                               : Shape
    
    @State var shapeName                    : String
    
    @State var radiusValue                  : Float = 0
    @State var radiusValueText              : String = ""
    
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
        
        if shape.shapeName == "Sphere" {
            self._radiusValue = State(initialValue: shape.radius)
            self._radiusValueText = State(initialValue: String(format: "%.02f", shape.radius))
        }
        
        self._noiseValue = State(initialValue: shape.noise)
        self._noiseValueText = State(initialValue: String(format: "%.02f", shape.noise))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(shape.name!)
                .onTapGesture(perform: {
                })
            
            Menu(content: {
                Button(action: {
                    shapeName = "Sphere"
                    save("Change shape")
                    model.build()
                }) {
                    Text("Sphere")
                }
                Button(action: {
                    shapeName = "Cube"
                    save("Change shape")
                    model.build()
                }) {
                    Text("Cube")
                }
            }, label: {
                Text(shapeName)
            })
        }
        
        if shapeName == "Sphere" {
            HStack {
                Text("Radius")
                
                Slider(value: Binding<Float>(get: {radiusValue}, set: { v in
                    radiusValue = v
                    radiusValueText = String(format: "%.02f", v)
                    shape.radius = v
                    model.build()
                    save("Radius")
                }), in: Float(0.001)...Float(0.5))
                
                Text(radiusValueText)
                    .frame(maxWidth: 40)
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
                MaterialView(model: model, project: project, point: point, shape: shape)
            }.padding()
        }
        
        //Section(header: Text("Modifier")) {
        
            Text("Modifier")
            .italic()
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
        //}

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
        
