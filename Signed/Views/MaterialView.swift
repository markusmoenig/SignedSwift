//
//  MaterialView.swift
//  Signed
//
//  Created by Markus Moenig on 24/9/23.
//

import Foundation

import SwiftUI
import Combine

#if os(iOS)
import MobileCoreServices
#endif

struct MaterialView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let model                               : Model
    var project                             : Project
    let point                               : Point
    let shape                               : Shape
    
    @State private var colorValue           = Color.gray
    
    @State var roughnessValue               : Float = 0
    @State var roughnessValueText           : String = ""
    
    @State var metallicValue                : Float = 0
    @State var metallicValueText            : String = ""
    
    init(model: Model, project: Project, point: Point, shape: Shape) {
        self.model = model
        self.project = project
        self.point = point
        self.shape = shape
        
        _colorValue = State(initialValue: Color(red: Double(shape.material!.red), green: Double(shape.material!.green), blue: Double(shape.material!.blue)))

        self._roughnessValue = State(initialValue: shape.material!.roughness)
        self._roughnessValueText = State(initialValue: String(format: "%.02f", shape.material!.roughness))
        self._metallicValue = State(initialValue: shape.material!.metallic)
        self._metallicValueText = State(initialValue: String(format: "%.02f", shape.material!.metallic))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            ColorPicker("Color", selection: $colorValue, supportsOpacity: false)
                .onChange(of: colorValue) { newValue in
                    if let cgColor = newValue.cgColor?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) {
                        
                        shape.material!.red = Float(cgColor.components![0])
                        shape.material!.green = Float(cgColor.components![1])
                        shape.material!.blue = Float(cgColor.components![2])
                        model.build()
                        
                        save("Material Color")
                    }
                }
            
            HStack {
                Text("Roughness")
                Slider(value: Binding<Float>(get: {roughnessValue}, set: { v in
                    roughnessValue = v
                    roughnessValueText = String(format: "%.02f", v)
                    shape.material!.roughness = v
                    model.build()
                    save("Roughness")
                }), in: Float(0.001)...Float(1.0))
                
                Text(roughnessValueText)
                    .frame(maxWidth: 40)
            }
            
            HStack {
                Text("Metallic")
                Slider(value: Binding<Float>(get: {metallicValue}, set: { v in
                    metallicValue = v
                    metallicValueText = String(format: "%.02f", v)
                    shape.material!.metallic = v
                    model.build()
                    save("Metallic")
                }), in: Float(0.001)...Float(1.0))
                
                Text(metallicValueText)
                    .frame(maxWidth: 40)
            }
            
            Spacer()
        }
        .frame(width: 200, height: 400)
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
        
