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
    let shape                               : Shape
    
    let nameWidth                           : CGFloat = 90

    @State private var colorValue           = Color.gray
    
    @State var subsurfaceValue              : Float = 0
    @State var metallicValue                : Float = 0
    @State var specularValue                : Float = 0
    @State var specularTintValue            : Float = 0
    @State var roughnessValue               : Float = 0
    @State var anisotropicValue             : Float = 0
    @State var sheenValue                   : Float = 0
    @State var sheenTintValue               : Float = 0
    @State var clearcoatValue               : Float = 0
    @State var clearcoatGlossValue          : Float = 0
    @State var transmissionValue            : Float = 0
    @State var iorValue                     : Float = 0
    @State var emissionValue                : Float = 0

    init(model: Model, project: Project, shape: Shape) {
        self.model = model
        self.project = project
        self.shape = shape
        
        _colorValue = State(initialValue: Color(red: Double(shape.material!.red), green: Double(shape.material!.green), blue: Double(shape.material!.blue)))

        self._subsurfaceValue = State(initialValue: shape.material!.subsurface)
        self._specularValue = State(initialValue: shape.material!.specular)
        self._specularTintValue = State(initialValue: shape.material!.specularTint)
        self._metallicValue = State(initialValue: shape.material!.metallic)
        self._roughnessValue = State(initialValue: shape.material!.roughness)
        self._anisotropicValue = State(initialValue: shape.material!.anisotropic)
        self._sheenValue = State(initialValue: shape.material!.sheen)
        self._sheenTintValue = State(initialValue: shape.material!.sheenTint)
        self._clearcoatValue = State(initialValue: shape.material!.clearcoat)
        self._transmissionValue = State(initialValue: shape.material!.transmission)
        self._iorValue = State(initialValue: shape.material!.ior)
        self._clearcoatGlossValue = State(initialValue: shape.material!.clearcoatGloss)
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            HStack {
                
                Text("Color")
                    .frame(width: nameWidth, alignment: .leading)
                
                ColorPicker("", selection: $colorValue, supportsOpacity: false)
                    .onChange(of: colorValue) { newValue in
                        if let cgColor = newValue.cgColor?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) {
                            
                            shape.material!.red = Float(cgColor.components![0])
                            shape.material!.green = Float(cgColor.components![1])
                            shape.material!.blue = Float(cgColor.components![2])
                            model.build()
                            
                            save("Material Color")
                        }
                    }
                    .padding(.leading, 0)
            }
            
            FloatView(name: "Subsurface", nameWidth: nameWidth, value: $subsurfaceValue, range: float2(0.0, 1.0))
                .onChange(of: subsurfaceValue, perform: { value in
                    shape.material!.subsurface = value
                    model.build()
                    save("Subsurface")
                })
            
            FloatView(name: "Metallic", nameWidth: nameWidth, value: $metallicValue, range: float2(0.0, 1.0))
                .onChange(of: metallicValue, perform: { value in
                    shape.material!.metallic = value
                    model.build()
                    save("Metallic")
                })
            
            FloatView(name: "Specular", nameWidth: nameWidth, value: $specularValue, range: float2(0.0, 1.0))
                .onChange(of: specularValue, perform: { value in
                    shape.material!.specular = value
                    model.build()
                    save("Specular")
                })
            
            FloatView(name: "Specular Tint", nameWidth: nameWidth, value: $specularTintValue, range: float2(0.0, 1.0))
                .onChange(of: specularTintValue, perform: { value in
                    shape.material!.specularTint = value
                    model.build()
                    save("Specular Tint")
                })
            
            FloatView(name: "Roughness", nameWidth: nameWidth, value: $roughnessValue, range: float2(0.0, 1.0))
                .onChange(of: roughnessValue, perform: { value in
                    shape.material!.roughness = value
                    model.build()
                    save("Roughness")
                })
            
            FloatView(name: "Anisotropic", nameWidth: nameWidth, value: $anisotropicValue, range: float2(0.0, 1.0))
                .onChange(of: anisotropicValue, perform: { value in
                    shape.material!.anisotropic = value
                    model.build()
                    save("Anisotropic")
                })
            
            FloatView(name: "Sheen", nameWidth: nameWidth, value: $sheenValue, range: float2(0.0, 1.0))
                .onChange(of: sheenValue, perform: { value in
                    shape.material!.sheen = value
                    model.build()
                    save("Sheen")
                })
            
            FloatView(name: "Sheen Tint", nameWidth: nameWidth, value: $sheenTintValue, range: float2(0.0, 1.0))
                .onChange(of: sheenTintValue, perform: { value in
                    shape.material!.sheenTint = value
                    model.build()
                    save("Sheen Tint")
                })
            
            FloatView(name: "Clearcoat", nameWidth: nameWidth, value: $clearcoatValue, range: float2(0.0, 1.0))
                .onChange(of: clearcoatValue, perform: { value in
                    shape.material!.clearcoat = value
                    model.build()
                    save("Clearcoat")
                })
            
            FloatView(name: "Clearcoat Gloss", nameWidth: nameWidth, value: $clearcoatGlossValue, range: float2(0.0, 1.0))
                .onChange(of: clearcoatGlossValue, perform: { value in
                    shape.material!.clearcoatGloss = value
                    model.build()
                    save("Clearcoat Gloss")
                })
            
            FloatView(name: "Transmission", nameWidth: nameWidth, value: $transmissionValue, range: float2(0.0, 1.0))
                .onChange(of: transmissionValue, perform: { value in
                    shape.material!.transmission = value
                    model.build()
                    save("Transmission")
                })
            
            FloatView(name: "IOR", nameWidth: nameWidth, value: $iorValue, range: float2(0.0, 2.0))
                .onChange(of: iorValue, perform: { value in
                    shape.material!.ior = value
                    model.build()
                    save("IOR")
                })
            
            FloatView(name: "Emission", nameWidth: nameWidth, value: $emissionValue, range: float2(0.0, 9.9))
                .onChange(of: emissionValue, perform: { value in
                    shape.material!.emission = value
                    model.build()
                    save("Emission")
                })
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 450)
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
        
