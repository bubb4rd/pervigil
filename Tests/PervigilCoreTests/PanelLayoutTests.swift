import Foundation
import Testing
@testable import PervigilCore

@Test func standardPanelShowsEverySectionWithStatusFirst() {
    let layout = PanelLayout.standard
    #expect(layout.visibleSections == [.status, .session, .triggers, .guards, .footer])
}

@Test func statusCanBeNeitherHiddenNorMoved() {
    var layout = PanelLayout.standard
    layout.setVisible(.status, false)
    #expect(layout.isVisible(.status))
    layout.move(.status, by: 1)
    #expect(layout.order.first == .status)
    #expect(!layout.canMove(.session, by: -1))
    layout.move(.session, by: -1)
    #expect(layout.order == PanelLayout.standard.order)
}

@Test func sectionsMoveAndHide() {
    var layout = PanelLayout.standard
    layout.move(.guards, by: -1)
    #expect(layout.order == [.status, .session, .guards, .triggers, .footer])
    #expect(!layout.canMove(.footer, by: 1))
    layout.setVisible(.triggers, false)
    #expect(layout.visibleSections == [.status, .session, .guards, .footer])
    layout.setVisible(.triggers, true)
    #expect(layout.isVisible(.triggers))
}

@Test func panelLayoutDecodingRepairsUnknownAndMissingSections() throws {
    let json = #"{"order":["footer","future","status","footer"],"hidden":["status","guards","future"]}"#
    let layout = try JSONDecoder().decode(PanelLayout.self, from: Data(json.utf8))
    #expect(layout.order == [.status, .footer, .session, .triggers, .guards])
    #expect(layout.hidden == [.guards])
}

@Test func migrationHidesASectionOnlyWhenAllItsRowsWereHidden() {
    var legacy = MenuLayout()
    legacy.hiddenItems = [.manualToggle, .duration, .quickStop, .manualOverride, .triggerAction, .triggerSummary]
    let panel = PanelLayout(migrating: legacy)
    #expect(panel.hidden == [.session])
    #expect(panel.isVisible(.triggers))
}

@Test func migrationTreatsAHiddenGroupAsHidingItsRows() {
    var legacy = MenuLayout()
    legacy.hiddenSections = [.quickSettings]
    let panel = PanelLayout(migrating: legacy)
    #expect(panel.hidden == [.guards])
}

@Test func migrationKeepsTheOrderTheRowsHad() {
    var legacy = MenuLayout()
    // Quick settings ahead of the manual session and triggers.
    legacy.sectionOrder = [.status, .quickSettings, .triggers, .manualSession]
    let panel = PanelLayout(migrating: legacy)
    #expect(panel.order == [.status, .guards, .triggers, .session, .footer])
}

@Test func minimalProfileMigratesToAStatusAndSessionPanel() {
    let panel = MenuLayout.profile(.minimal).panel
    #expect(panel.isVisible(.session))
    #expect(!panel.isVisible(.triggers))
    #expect(!panel.isVisible(.guards))
    #expect(!panel.isVisible(.footer))
}

@Test func savedLayoutWithoutSectionsMigratesWhenDecoded() throws {
    // A layout saved by a build from before the section redesign.
    let json = #"{"hiddenItems":["closedDisplay","brewingOnly","lidPolicy","batteryPause","batteryThreshold","displaySleep","keepActive","dimDisplay","screenSaverYield"]}"#
    let layout = try JSONDecoder().decode(MenuLayout.self, from: Data(json.utf8))
    #expect(layout.panel.hidden == [.guards])
    // Once saved, the sections are stored and win over the rows.
    var edited = layout
    edited.panel.setVisible(.guards, true)
    let restored = try JSONDecoder().decode(MenuLayout.self, from: JSONEncoder().encode(edited))
    #expect(restored.panel.isVisible(.guards))
    #expect(restored.hiddenItems.contains(.closedDisplay))
}

@Test func settingsCarryThePanelLayoutThroughARoundTrip() throws {
    var settings = PervigilSettings.default
    var layout = MenuLayout()
    layout.panel.move(.footer, by: -1)
    layout.panel.setVisible(.triggers, false)
    settings.setMenuLayout(layout)
    settings.menuCustomizationEnabled = true
    let restored = try JSONDecoder().decode(PervigilSettings.self, from: JSONEncoder().encode(settings))
    #expect(restored.customizedMenuLayout?.panel == layout.panel)
}
