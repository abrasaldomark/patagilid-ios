//
//  SharedFilterComponents.swift
//  PataGilid
//
//  Shared, DRY filter components used by both MountainsListView and SummitLogsView.
//

import SwiftUI

// MARK: - Island Group Filter Bar

/// A horizontal scrolling bar with "All", island group pills, and dismissable active-filter badges.
/// Used identically by the Mountains tab and the My Climbs tab.
struct IslandGroupFilterBar<ExtraBadges: View>: View {
    let allCount: Int
    let selectedIslandGroup: IslandGroup?
    let selectedRegion: String?
    let isAllSelected: Bool
    let onResetFilters: () -> Void
    let onSelectIslandGroup: (IslandGroup) -> Void
    let onClearRegion: () -> Void
    @ViewBuilder var extraBadges: () -> ExtraBadges
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterPill(title: "All (\(allCount))", assetImage: "philippines_icon", isSelected: isAllSelected) {
                    onResetFilters()
                }
                
                ForEach(IslandGroup.allCases) { group in
                    FilterPill(title: group.rawValue, systemImage: group.systemImageName, assetImage: group.assetImageName, isSelected: selectedIslandGroup == group) {
                        onSelectIslandGroup(group)
                    }
                }
                
                extraBadges()
                
                // Active Region Badge indicator
                if let activeRegion = selectedRegion {
                    DismissableBadge(
                        label: activeRegion,
                        color: .orange,
                        onDismiss: onClearRegion
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color.secondary.opacity(0.06))
    }
}

// Convenience initializer when there are no extra badges
extension IslandGroupFilterBar where ExtraBadges == EmptyView {
    init(
        allCount: Int,
        selectedIslandGroup: IslandGroup?,
        selectedRegion: String?,
        isAllSelected: Bool,
        onResetFilters: @escaping () -> Void,
        onSelectIslandGroup: @escaping (IslandGroup) -> Void,
        onClearRegion: @escaping () -> Void
    ) {
        self.allCount = allCount
        self.selectedIslandGroup = selectedIslandGroup
        self.selectedRegion = selectedRegion
        self.isAllSelected = isAllSelected
        self.onResetFilters = onResetFilters
        self.onSelectIslandGroup = onSelectIslandGroup
        self.onClearRegion = onClearRegion
        self.extraBadges = { EmptyView() }
    }
}

// MARK: - Dismissable Badge

/// A capsule badge with an "×" icon that dismisses a filter when tapped.
/// Used for active region and outcome filter indicators.
struct DismissableBadge: View {
    let label: String
    let color: Color
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .lineLimit(1)
            Image(systemName: "xmark.circle.fill")
        }
        .font(.caption)
        .fontWeight(.bold)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .clipShape(Capsule())
        .onTapGesture {
            onDismiss()
        }
    }
}

// MARK: - Count Banner

/// A slim banner showing "Showing X of Y <noun>".
struct CountBanner: View {
    let filteredCount: Int
    let totalCount: Int
    let noun: String
    
    var body: some View {
        HStack {
            Text("Showing \(filteredCount) of \(totalCount) \(noun)")
                .font(.caption)
                .foregroundColor(.gray)
                .contentTransition(.numericText(value: Double(totalCount)))
                .animation(.snappy, value: totalCount)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

// MARK: - Search & Filter Toolbar

/// The magnifying glass + filter menu toolbar group shared by Mountains and My Climbs.
struct SearchFilterToolbar<MenuContent: View>: View {
    @Binding var isSearchVisible: Bool
    var onAdd: (() -> Void)? = nil
    @ViewBuilder var menuContent: () -> MenuContent
    
    var body: some View {
        HStack(spacing: 12) {
            if let onAdd {
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gliderBlue)
                }
            }
            Button {
                isSearchVisible = true
            } label: {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gliderBlue)
            }
            
            Menu {
                menuContent()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gliderBlue)
            }
        }
    }
}

// MARK: - Region Filter Menu Section

/// A reusable "Filter by Region" menu section with "All Regions" and a list of available regions.
struct RegionFilterMenuSection: View {
    let availableRegions: [String]
    let selectedRegion: String?
    let onSelectRegion: (String?) -> Void
    
    var body: some View {
        Section(header: Text("Filter by Region")) {
            Button(action: { onSelectRegion(nil) }) {
                Text("All Regions")
            }
            
            ForEach(availableRegions, id: \.self) { region in
                Button(action: { onSelectRegion(region) }) {
                    HStack {
                        Text(region)
                        if selectedRegion == region {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sort Order Menu Section

/// A generic "Sort Order" menu section for any RawRepresentable/CaseIterable enum.
struct SortOrderMenuSection<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    let currentOrder: T
    let onSelect: (T) -> Void
    
    var body: some View {
        Section(header: Text("Sort Order")) {
            ForEach(T.allCases, id: \.self) { order in
                Button(action: { onSelect(order) }) {
                    HStack {
                        Text(order.rawValue)
                        if currentOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Filter Pill

/// A capsule-shaped toggle pill used within the Island Group Filter Bar.
struct FilterPill: View {
    let title: String
    var systemImage: String? = nil
    var assetImage: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                } else if let assetImage = assetImage {
                    Image(assetImage)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                Text(title)
            }
                .font(.caption)
                .fontWeight(isSelected ? .bold : .semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.gliderBlue : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.gliderBlue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
    }
}
