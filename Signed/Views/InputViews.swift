//
//  InputViews.swift
//  Signed
//
//  Created by Markus Moenig on 28/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct FloatView: View {
    
    let name                                : String
    let nameWidth                           : CGFloat
    let range                               : float2

    @Binding var floatValue                 : Float
    @State private var floatValueText       : String

    @State private var editPopover          : Bool = false

    init(name: String, nameWidth: CGFloat, value: Binding<Float>, range: float2) {
        self.name = name
        self.nameWidth = nameWidth
        self.range = range
        self._floatValue = value
        self._floatValueText = State(initialValue: String(format: "%.03f", value.wrappedValue))
    }
 
    var body: some View {
        HStack {
            Text(name)
                .frame(width: nameWidth, alignment: .leading)
            
            Slider(value: Binding<Float>(get: {floatValue}, set: { v in
                floatValue = v
                floatValueText = String(format: "%.03f", v)
            }), in: range.x...range.y)
            
            Text(floatValueText)
                .frame(maxWidth: 45)
                .onTapGesture {
                    editPopover = true
                }
        }
        .popover(isPresented: $editPopover,
                 arrowEdge: .top
        ) {
            VStack(alignment: .leading) {
                Text(name)
                HStack {
                    
                    TextField("Value", text: $floatValueText)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                        .onReceive(Just(floatValueText)) { newValue in
                            let filtered = newValue.filter { "0123456789.-+".contains($0) }
                            if filtered == newValue {
                                if let v = Float(newValue) {
                                    floatValue = v
                                }
                            }
                        }
                }
            }
            .frame(width: 150)
            .padding()
        }
    }
}
