//
//  Replace.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 21.06.22.
//

/// Replacing a view with a nice fade animation.
///     Together with Collapse animations, this should allow us to animate any UI state changes we desire

import Foundation
import Cocoa

extension NSView {
    
    /// Interface
    
    func animatedReplace(with view: NSView) {
        
        /// Copy over all constraints from self to the new view
        ///    (Except height and width)
        
        ReplaceAnimations.animate(ogView: self, replaceView: view, hAnchor: .leading, vAnchor: .center, doAnimate: true)
    }
    
    func unanimatedReplace(with view: NSView) {
        ReplaceAnimations.animate(ogView: self, replaceView: view, hAnchor: .leading, vAnchor: .center, doAnimate: false)
    }
}


class ReplaceAnimations {
    
    /// Storage
    
    private static var _fadeInDelayDispatchQueues: [NSView: DispatchQueue] = [:]
    private static func fadeInDelayDispatchQueue(forView view: NSView) -> DispatchQueue {
        if let cachedQueue = _fadeInDelayDispatchQueues[view] {
            return cachedQueue
        } else {
            let newQueue = DispatchQueue.init(label: "com.nuebling.mac-mouse-fix.fadeInDelay.\(view.hash)", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: nil)
            _fadeInDelayDispatchQueues[view] = newQueue
            return newQueue
        }
    }
    
    /// Core function

    static func animate(ogView: NSView, replaceView: NSView, hAnchor: MFHAnchor, vAnchor: MFVAnchor, doAnimate: Bool, onComplete: @escaping () -> () = { }){
        
        /// Parameter explanation:
        ///     The animation produces the following changes:
        ///         1. Size change -> The 'feel' is controlled by `animationCurve`
        ///         2. Fade out of `ogView` / Fade in of `replaceView` -> The 'feel' is controlled by `fadeOverlap`
        ///     `duration` controls the duration of all changes that the animation makes
        ///     `hAnchor` and `vAnchor` determine how the ogView and replaceView are aligned with the wrapperView during resizing. If the size doesn't change this doesn't have an effect
        
        /// The `replaceView` may have width and height constraints but it shouldn't have any constraints to a superview I think (It will take over the superview constraints from `ogView`)
        
        /// Fadeoverlap should be between -1 and 1
        
        
        /// Validate
        assert(!ogView.translatesAutoresizingMaskIntoConstraints)
        assert(!replaceView.translatesAutoresizingMaskIntoConstraints)
        
        /// Constants
        
        let sizeChangeCurve = CAMediaTimingFunction(name: .default)
        
        /// These are lifted from TabViewController
        var fadeOutCurve: CAMediaTimingFunction
//        fadeOutCurve = .init(controlPoints: 0.25, 0.1, 0.25, 1.0) /* default */
//        fadeOutCurve = .init(controlPoints: 0.0, 0.0, 0.25, 1.0)
//        fadeOutCurve = .init(controlPoints: 0.0, 0.5, 0.0, 1.0)
//        fadeOutCurve = .init(controlPoints: 0.0, 0.5, 0.0, 1.0)
        fadeOutCurve = .init(controlPoints: 0.0, 0.5, 0.0, 1.0) /// For new spring animation
        var fadeInCurve: CAMediaTimingFunction
//        fadeInCurve = .init(controlPoints: 0.45, 0, 0.7, 1) /* strong ease in */
//        fadeInCurve = .init(controlPoints: 0.8, 0, 1, 1)
//        fadeInCurve = .init(controlPoints: 0.75, 0.1, 0.75, 1) /* inverted default */
//        fadeInCurve = .init(controlPoints: 0.25, 0.1, 0.25, 1) /* default */
        fadeInCurve = .init(controlPoints: 0.0, 0.0, 0.5, 1.0) /// For new spring animation
        
        
        ///
        /// Store size of ogView
        ///
        
        ogView.superview?.needsLayout = true
        ogView.superview?.layoutSubtreeIfNeeded()
        
        let ogSize = ogView.size()
        
        /// Debug
        
        for const in ogView.constraints {
            if const.firstAttribute == .width {
                print("widthConst: \(const), fittingSize: \(ogSize)")
            }
        }
        
        ///
        /// Store image of ogView
        ///
        let ogImage = ogView.takeImage()
        
        ///
        /// Measure replaceView size in layout
        ///
        let replaceConstraints = transferSuperViewConstraints(fromView: ogView, toView: replaceView, transferSizeConstraints: false)
        ogView.superview?.replaceSubview(ogView, with: replaceView)
        for cnst in replaceConstraints {
            cnst.isActive = true
        }
        replaceView.superview?.needsLayout = true
        replaceView.superview?.layoutSubtreeIfNeeded()
        
        let replaceSize = replaceView.size()
        
        ///
        /// Store image of replaceView
        ///
        let replaceImage = replaceView.takeImage()
        
        ///
        /// Get animationDuration
        ///
        
        let animationDistance = max(abs(replaceSize.width - ogSize.width), abs(replaceSize.height - ogSize.height))
        var duration = getAnimationDuration(animationDistance: animationDistance)
        
        ///
        /// Create `wrapperView` for animating and replace `replaceView`
        ///
        
        /// We replace `replaceView` instead of `ogView` because we've already replaced `ogView` for measuring its size in the layout.
        
        let wrapperView = NoClipWrapper()
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.wantsLayer = true
        wrapperView.layer?.masksToBounds = false /// Don't think is necessary for NoClipWrapper()
        var wrapperConstraints = transferSuperViewConstraints(fromView: replaceView, toView: wrapperView, transferSizeConstraints: false)
        let wrapperWidthConst = wrapperView.widthAnchor.constraint(equalToConstant: ogSize.width)
        let wrapperHeightConst = wrapperView.heightAnchor.constraint(equalToConstant: ogSize.height)
        wrapperConstraints.append(wrapperWidthConst)
        wrapperConstraints.append(wrapperHeightConst)
        replaceView.superview?.replaceSubview(replaceView, with: wrapperView)
        for cnst in wrapperConstraints {
            cnst.isActive = true
        }
        
        ///
        /// Create before / after image views for animating
        ///
        let ogImageView = NSImageView()
        ogImageView.translatesAutoresizingMaskIntoConstraints = false
        ogImageView.imageScaling = .scaleNone
        
        ogImageView.image = ogImage
        ogImageView.widthAnchor.constraint(equalToConstant: ogSize.width).isActive = true
        ogImageView.heightAnchor.constraint(equalToConstant: ogSize.height).isActive = true
        
        let replaceImageView = NSImageView()
        replaceImageView.translatesAutoresizingMaskIntoConstraints = false
        replaceImageView.imageScaling = .scaleNone
        
        replaceImageView.image = replaceImage
        replaceImageView.widthAnchor.constraint(equalToConstant: replaceSize.width).isActive = true
        replaceImageView.heightAnchor.constraint(equalToConstant: replaceSize.height).isActive = true
        
        ///
        /// Add in both imageViews into wrapperView and add constraints
        ///
        wrapperView.addSubview(ogImageView)
        wrapperView.addSubview(replaceImageView)
        
        switch hAnchor {
        case .leading:
            ogImageView.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor).isActive = true
            replaceImageView.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor).isActive = true
        case .center:
            ogImageView.centerXAnchor.constraint(equalTo: wrapperView.centerXAnchor).isActive = true
            replaceImageView.centerXAnchor.constraint(equalTo: wrapperView.centerXAnchor).isActive = true
        case .trailing:
            ogImageView.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor).isActive = true
            replaceImageView.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor).isActive = true
        }
        switch vAnchor {
        case .top:
            ogImageView.topAnchor.constraint(equalTo: wrapperView.topAnchor).isActive = true
            replaceImageView.topAnchor.constraint(equalTo: wrapperView.topAnchor).isActive = true
        case .center:
            ogImageView.centerYAnchor.constraint(equalTo: wrapperView.centerYAnchor).isActive = true
            replaceImageView.centerYAnchor.constraint(equalTo: wrapperView.centerYAnchor).isActive = true
        case .bottom:
            ogImageView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor).isActive = true
            replaceImageView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor).isActive = true
        }
        
        ///
        /// Force layout to initial animation state (Probably not necessary)
        ///
        
        wrapperView.superview?.needsLayout = true
        wrapperView.superview?.layoutSubtreeIfNeeded()
        
        ///
        /// Animate size of wrapperView
        ///
        let animation: CAAnimation
        if doAnimate {
            animation = CASpringAnimation(speed: 3.7, damping: 1.0)
        } else {
            animation = CABasicAnimation(name: .linear, duration: 0.0)
        }
        
        Animate.with(animation, changes: {
            wrapperWidthConst.reactiveAnimator().constant.set(replaceSize.width)
            wrapperHeightConst.reactiveAnimator().constant.set(replaceSize.height)
        }, onComplete: {
            /// Replace wrapper (and imageViews) with replaceView
            wrapperView.superview?.replaceSubview(wrapperView, with: replaceView)
            for const in replaceConstraints {
                const.isActive = true
            }
            /// Call onComplete
            onComplete()
        })
        
        ///
        /// Animate opacities
        ///
        
        /// Override duration because we're using spring animation now (clean this up)
        duration = max(animation.duration * 0.55, 0.18)
        
        /// Set initial opacities
        ogImageView.alphaValue = 1.0
        replaceImageView.alphaValue = 0.0
        
        /// Fade out view
        Animate.with(CABasicAnimation(curve: fadeOutCurve, duration: duration)) {
            ogImageView.reactiveAnimator().alphaValue.set(0.0)
        }
        
        /// Fade in view
        Animate.with(CABasicAnimation(curve: fadeInCurve, duration: duration)) {
            replaceImageView.reactiveAnimator().alphaValue.set(1.0)
        }
    }
    
    /// Helper
    
    private static func getAnimationDuration(animationDistance: Double) -> CFTimeInterval {
        
        /// This is lifted from Collapse.swift
        
        /// Slow down large animations a little for consistent feel
        let baseDuration = 0.25
        let speed = 180 /// px per second. Duration can be based on this. For some reasons large animations were way too slow with this
        let proportionalDuration = abs(animationDistance) / Double(speed)
        let normalizationFactor = 0.9
        let duration = (1-normalizationFactor) * proportionalDuration + (normalizationFactor) * baseDuration
        
        return duration
    }
}
