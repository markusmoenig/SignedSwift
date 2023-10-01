//
//  MaterialPicker.swift
//  Signed
//
//  Created by Markus Moenig on 1/10/23.
//

import Foundation

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct MaterialPicker: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let model                               : Model
    
    @Binding var materialId                 : UUID?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Material.index, ascending: true)],
        animation: .default)
    
    private var materials                   : FetchedResults<Material>

    init(model: Model, id: Binding<UUID?>) {
        self.model = model
        self._materialId = id
     }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            List {
                ForEach(materials) { material in
                    Text(material.name!)
                        .onTapGesture {
                            _materialId.wrappedValue = material.id
                        }
                        .foregroundStyle(material.id == materialId ? Color.accentColor : Color.primary)
                }
            }
            .listStyle(PlainListStyle())
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

