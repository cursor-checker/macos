import SwiftUI

struct MenuBarSettingsSection: View {
    @Binding var menuBarVisible: Bool
    @Binding var menuBarMode: MenuBarPercentMode
    @Binding var menuBarWarningIconEnabled: Bool
    @Binding var menuPopupFields: MenuPopupFields
    var onMenuPopupFieldChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Card {
                SettingsRow(L10n.menuBarShowInMenuBar, subtitle: L10n.menuBarShowInMenuBarHint) {
                    SettingsControls.switchToggle($menuBarVisible)
                }
                RowDivider()
                SettingsRow(L10n.menuBarTitle, subtitle: L10n.menuBarTitleHint, isEnabled: menuBarVisible) {
                    Picker("", selection: $menuBarMode) {
                        ForEach(MenuBarPercentMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 220, alignment: .trailing)
                    .settingsControlEnabled(menuBarVisible)
                }
                RowDivider()
                SettingsRow(
                    L10n.menuBarWarningIcon,
                    subtitle: L10n.menuBarWarningIconHint,
                    isEnabled: menuBarVisible
                ) {
                    SettingsControls.switchToggle($menuBarWarningIconEnabled)
                        .settingsControlEnabled(menuBarVisible)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionHeader(title: L10n.menuBarDropdown)
                    .padding(.leading, SettingsLayout.sectionHeaderIndent)
                Text(L10n.menuBarReorderHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, SettingsLayout.sectionHeaderIndent)
                menuPopupFieldsList
            }
        }
    }

    private var menuPopupFieldsList: some View {
        List {
            ForEach(menuPopupFields.resolvedFieldOrder) { field in
                HStack(spacing: 8) {
                    reorderHandle
                    SettingsRow(field.title) {
                        SettingsControls.switchToggle(menuPopupFieldBinding(field))
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.visible, edges: .bottom)
                .listRowSeparatorTint(Color(nsColor: .separatorColor).opacity(0.35))
                .listRowBackground(SettingsColors.cardBackground)
            }
            .onMove(perform: moveMenuPopupField)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .frame(height: menuPopupListHeight)
        .background(SettingsColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .environment(\.defaultMinListRowHeight, 44)
    }

    private var reorderHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(90))
            .frame(width: 14)
            .padding(.leading, 12)
            .accessibilityLabel(L10n.menuBarReorderAccessibility)
    }

    private var menuPopupListHeight: CGFloat {
        CGFloat(menuPopupFields.resolvedFieldOrder.count) * 44
    }

    private func moveMenuPopupField(from source: IndexSet, to destination: Int) {
        menuPopupFields.moveFields(from: source, to: destination)
        onMenuPopupFieldChange()
    }

    private func menuPopupFieldBinding(_ field: MenuPopupField) -> Binding<Bool> {
        Binding(
            get: { menuPopupFields.isEnabled(field) },
            set: {
                menuPopupFields.setEnabled(field, $0)
                onMenuPopupFieldChange()
            }
        )
    }
}
