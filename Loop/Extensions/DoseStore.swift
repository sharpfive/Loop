//
//  DoseStore.swift
//  Loop
//
//  Created by Nate Racklyeft on 7/31/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import InsulinKit
import MinimedKit


// Bridges support for MinimedKit data types
extension DoseStore {
    /**
     Adds and persists new pump events.
     */
    func add(_ pumpEvents: [TimestampedHistoryEvent], completionHandler: @escaping (_ error: DoseStore.DoseStoreError?) -> Void) {
        var events: [NewPumpEvent] = []
        var lastTempBasalAmount: DoseEntry?
        var title: String

        for event in pumpEvents {
            var type: InsulinKit.PumpEventType?
            var dose: DoseEntry?

            switch event.pumpEvent {
            case let bolus as BolusNormalPumpEvent:
                let unit: DoseUnit

                switch bolus.type {
                case .Normal:
                    unit = .units
                case .Square:
                    unit = .unitsPerHour
                }

                dose = DoseEntry(type: .bolus, startDate: event.date, endDate: event.date.addingTimeInterval(bolus.duration), value: bolus.amount, unit: unit)
            case is SuspendPumpEvent:
                dose = DoseEntry(suspendDate: event.date)
            case is ResumePumpEvent:
                dose = DoseEntry(resumeDate: event.date)
            case let temp as TempBasalPumpEvent:
                if case .Absolute = temp.rateType {
                    lastTempBasalAmount = DoseEntry(type: .tempBasal, startDate: event.date, value: temp.rate, unit: .unitsPerHour)
                }
            case let temp as TempBasalDurationPumpEvent:
                if let amount = lastTempBasalAmount, amount.startDate == event.date {
                    dose = DoseEntry(
                        type: .tempBasal,
                        startDate: event.date,
                        endDate: event.date.addingTimeInterval(TimeInterval(minutes: Double(temp.duration))),
                        value: amount.value,
                        unit: amount.unit
                    )
                }
            case is PrimePumpEvent:
                // The type of the eventual PumpEvent is set through the dose. But dose is undefined in a Prime
                type = .prime
            default:
                break
            }

            title = String(describing: event.pumpEvent)
            
            // The type parameter of the eventual PumpEvent is set via the dose.type, except for prime events
            events.append(NewPumpEvent(date: event.date, dose: dose, isMutable: event.isMutable(), raw: event.pumpEvent.rawData, title: title, type: type))
        }

        addPumpEvents(events, completion: completionHandler)
    }
}
