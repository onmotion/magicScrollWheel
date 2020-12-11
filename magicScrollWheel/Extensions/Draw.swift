//
//  Draw.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 19.04.2020.
//  Copyright © 2020 Aleksandr Kozhevnikov. All rights reserved.
//

import Foundation
import BezierKit

extension Draw {
    
    public static func drawSkeleton(_ context: CGContext,
                                    curve: BezierCurve,
                                    offset: CGPoint=CGPoint(x: 0.0, y: 0.0),
                                    coords: Bool=true) {

        context.setStrokeColor(lightGrey) // lines to control points

        if let cubicCurve = curve as? CubicCurve {
            self.drawLine(context, from: cubicCurve.p0, to: cubicCurve.p1, offset: offset)
            self.drawLine(context, from: cubicCurve.p2, to: cubicCurve.p3, offset: offset)
        } else if let quadraticCurve = curve as? QuadraticCurve {
            self.drawLine(context, from: quadraticCurve.p0, to: quadraticCurve.p1, offset: offset)
            self.drawLine(context, from: quadraticCurve.p1, to: quadraticCurve.p2, offset: offset)
        }

        if coords == true {
            context.setStrokeColor(red)
            context.setFillColor(red)
            self.drawPoints(context, points: curve.points, offset: offset)
            context.setFillColor(.clear)
            context.setStrokeColor(black) // curve
        }
    }
    
    public static func drawPoints(_ context: CGContext,
                                  points: [CGPoint],
                                  offset: CGPoint=CGPoint(x: 0.0, y: 0.0)) {
        for p in points {
            self.drawCircle(context, center: p, radius: 6.0, offset: offset)
        }
    }
    
    public static func drawCircle(_ context: CGContext, center: CGPoint, radius r: CGFloat, offset: CGPoint = .zero) {
        context.beginPath()
        context.addEllipse(in: CGRect(origin: CGPoint(x: center.x - r + offset.x, y: center.y - r + offset.y),
                            size: CGSize(width: 2.0 * r, height: 2.0 * r))
                            )
        context.closePath()
        context.drawPath(using: .fillStroke)
    }
}
