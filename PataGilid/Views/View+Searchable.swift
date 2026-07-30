//
//  View+Searchable.swift
//  PataGilid
//
//  Created by Mark Abrasaldo on 7/30/26.
//

import SwiftUI

extension View {
    /// Applies `.searchable` only when `isPresented` is true, keeping the default navigation search textfield removed from the UI when search is inactive.
    @ViewBuilder
    func conditionalSearchable(
        text: Binding<String>,
        isPresented: Binding<Bool>,
        prompt: String
    ) -> some View {
        if isPresented.wrappedValue {
            self.searchable(text: text, isPresented: isPresented, prompt: prompt)
        } else {
            self
        }
    }
}
