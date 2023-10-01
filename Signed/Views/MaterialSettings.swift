//
//  MaterialView.swift
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

struct MaterialSettings: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let model                               : Model
    let material                            : Material
    
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

    init(model: Model, material: Material) {
        self.model = model
        self.material = material
        
        _colorValue = State(initialValue: Color(red: Double(material.red), green: Double(material.green), blue: Double(material.blue)))

        self._subsurfaceValue = State(initialValue: material.subsurface)
        self._specularValue = State(initialValue: material.specular)
        self._specularTintValue = State(initialValue: material.specularTint)
        self._metallicValue = State(initialValue: material.metallic)
        self._roughnessValue = State(initialValue: material.roughness)
        self._anisotropicValue = State(initialValue: material.anisotropic)
        self._sheenValue = State(initialValue: material.sheen)
        self._sheenTintValue = State(initialValue: material.sheenTint)
        self._clearcoatValue = State(initialValue: material.clearcoat)
        self._transmissionValue = State(initialValue: material.transmission)
        self._iorValue = State(initialValue: material.ior)
        self._clearcoatGlossValue = State(initialValue: material.clearcoatGloss)
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            HStack {
                
                Text("Color")
                    .frame(width: nameWidth, alignment: .leading)
                
                ColorPicker("", selection: $colorValue, supportsOpacity: false)
                    .onChange(of: colorValue) { newValue in
                        if let cgColor = newValue.cgColor?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) {
                            
                            material.red = Float(cgColor.components![0])
                            material.green = Float(cgColor.components![1])
                            material.blue = Float(cgColor.components![2])
                            model.build()
                            
                            save("Material Color")
                        }
                    }
                    .padding(.leading, 0)
            }
            
            FloatView(name: "Subsurface", nameWidth: nameWidth, value: $subsurfaceValue, range: float2(0.0, 1.0))
                .onChange(of: subsurfaceValue, perform: { value in
                    material.subsurface = value
                    model.build()
                    save("Subsurface")
                })
            
            FloatView(name: "Metallic", nameWidth: nameWidth, value: $metallicValue, range: float2(0.0, 1.0))
                .onChange(of: metallicValue, perform: { value in
                    material.metallic = value
                    model.build()
                    save("Metallic")
                })
            
            FloatView(name: "Specular", nameWidth: nameWidth, value: $specularValue, range: float2(0.0, 1.0))
                .onChange(of: specularValue, perform: { value in
                    material.specular = value
                    model.build()
                    save("Specular")
                })
            
            FloatView(name: "Specular Tint", nameWidth: nameWidth, value: $specularTintValue, range: float2(0.0, 1.0))
                .onChange(of: specularTintValue, perform: { value in
                    material.specularTint = value
                    model.build()
                    save("Specular Tint")
                })
            
            FloatView(name: "Roughness", nameWidth: nameWidth, value: $roughnessValue, range: float2(0.0, 1.0))
                .onChange(of: roughnessValue, perform: { value in
                    material.roughness = value
                    model.build()
                    save("Roughness")
                })
            
            FloatView(name: "Anisotropic", nameWidth: nameWidth, value: $anisotropicValue, range: float2(0.0, 1.0))
                .onChange(of: anisotropicValue, perform: { value in
                    material.anisotropic = value
                    model.build()
                    save("Anisotropic")
                })
            
            FloatView(name: "Sheen", nameWidth: nameWidth, value: $sheenValue, range: float2(0.0, 1.0))
                .onChange(of: sheenValue, perform: { value in
                    material.sheen = value
                    model.build()
                    save("Sheen")
                })
            
            FloatView(name: "Sheen Tint", nameWidth: nameWidth, value: $sheenTintValue, range: float2(0.0, 1.0))
                .onChange(of: sheenTintValue, perform: { value in
                    material.sheenTint = value
                    model.build()
                    save("Sheen Tint")
                })
            
            FloatView(name: "Clearcoat", nameWidth: nameWidth, value: $clearcoatValue, range: float2(0.0, 1.0))
                .onChange(of: clearcoatValue, perform: { value in
                    material.clearcoat = value
                    model.build()
                    save("Clearcoat")
                })
            
            FloatView(name: "Clearcoat Gloss", nameWidth: nameWidth, value: $clearcoatGlossValue, range: float2(0.0, 1.0))
                .onChange(of: clearcoatGlossValue, perform: { value in
                    material.clearcoatGloss = value
                    model.build()
                    save("Clearcoat Gloss")
                })
            
            FloatView(name: "Transmission", nameWidth: nameWidth, value: $transmissionValue, range: float2(0.0, 1.0))
                .onChange(of: transmissionValue, perform: { value in
                    material.transmission = value
                    model.build()
                    save("Transmission")
                })
            
            FloatView(name: "IOR", nameWidth: nameWidth, value: $iorValue, range: float2(0.0, 2.0))
                .onChange(of: iorValue, perform: { value in
                    material.ior = value
                    model.build()
                    save("IOR")
                })
            
            FloatView(name: "Emission", nameWidth: nameWidth, value: $emissionValue, range: float2(0.0, 9.9))
                .onChange(of: emissionValue, perform: { value in
                    material.emission = value
                    model.build()
                    save("Emission")
                })
            
            Spacer()
        }
        .padding()
        #if os(iOS)
        .frame(width: 300, height: 600)
        #else
        .frame(width: 300, height: 450)
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

