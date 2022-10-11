//
//  ViewImpressionTracker.swift
//  ViewImpression
//
//  Created by Taichi Yuki on 2022/10/04.
//

import UIKit
import ReactiveKit
import Bond

// MARK: - Extensions
private extension UITableView {
  /// 現在のoffsetを元に、相対的なframeを取得する
  var currentContentRect: CGRect {
    CGRect(
      x: self.contentOffset.x,
      y: self.contentOffset.y,
      width: self.bounds.width,
      height: self.bounds.height
    )
  }
}

// MARK: - TableViewImpressionTrackable
protocol TableViewImpressionTrackable where Self: UIViewController {
  var tableView: UITableView { get }
  var impressionTracker: TableViewImpressionTracker { get }
}

extension TableViewImpressionTrackable {
  func setupImpressionTracker() {
    impressionTracker.setup(with: tableView)
  }
}

// MARK: - TableViewImpressionTracker
final class TableViewImpressionTracker {
  struct ThresholdPoints {
    let topPoint: CGPoint
    let bottomPoint: CGPoint
  }

  private let config: Configuration
  private var trackedIndexPaths: Set<IndexPath> = []
  private let indexPathForTracking = Observable<IndexPath>([])
  var trackingIndexPath: Signal<IndexPath, Never> {
    indexPathForTracking.toSignal()
  }

  init(config: Configuration = .default) {
    self.config = config
  }

  func setup(with tableView: UITableView) {
    bind(tableView: tableView)
  }

  private func bind(tableView: UITableView) {
    let indexPathsForVisibleRows = tableView.reactive.keyPath(\.indexPathsForVisibleRows)
    tableView.reactive.keyPath(\.contentOffset) // contentOffset の変化を監視
      .flatMapLatest { _ in
        // offset 変化時に画面表示中の Cell の index を全て取得
        indexPathsForVisibleRows
      }
      .ignoreNils()
      .flattenElements()
      .filter { [unowned self] visibleIndexPath in
        // 画面表示中の Cell のうち、計測対象の閾値を満たす Cell の Index にフィルタする
        self.containsCurrentContentRect(in: tableView, at: visibleIndexPath)
      }
      .removeDuplicates()
      .flatMapMerge { [unowned self] trackingIndexPath in
        self.checkCellDisplayedContinuously(in: tableView, at: trackingIndexPath)
      }
      .filter { [unowned self] trackingIndexPath in
        /// 一度表示（計測）された Cell の Index はキャッシュして、重複してイベントを流さない
        if self.trackedIndexPaths.contains(trackingIndexPath) { return false }
        self.trackedIndexPaths.insert(trackingIndexPath)
        return true
      }
      .bind(to: indexPathForTracking)
  }

  private func getThresholdPoints(from originalRect: CGRect) -> ThresholdPoints {
    let topPoint = originalRect.origin
    let bottomPoint = CGPoint(x: originalRect.origin.x, y: originalRect.maxY)

    let thresholdRatio = config.trackingCellHeightRetio
    let thresholdHeight = originalRect.size.height * CGFloat(thresholdRatio)

    return ThresholdPoints(
      topPoint: CGPoint(x: topPoint.x, y: topPoint.y + thresholdHeight),
      bottomPoint: CGPoint(x: bottomPoint.x, y: bottomPoint.y - thresholdHeight)
    )
  }

  /// 評価対象のCellのIndexが、「表示中」の閾値を満たしているかどうか
  private func containsCurrentContentRect(in tableView: UITableView, at indexPath: IndexPath) -> Bool {
    let tableViewCurrentContentRect = tableView.currentContentRect

    guard let cell = tableView.cellForRow(at: indexPath) else { return false }
    let cellRect = cell.contentView.convert(cell.contentView.bounds, to: tableView)
    let thresholdPoints = getThresholdPoints(from: cellRect)

    return tableViewCurrentContentRect.contains(thresholdPoints.topPoint)
      && tableViewCurrentContentRect.contains(thresholdPoints.bottomPoint)
  }

  /// 評価対象のCellのIndexが、n秒間表示され続けたかを0.5秒間隔でチェックする
  private func checkCellDisplayedContinuously(in tableView: UITableView, at indexPath: IndexPath) ->  Signal<IndexPath, Never> {
    var limitSecond = config.trackingImpressionSecond
    let interval = 0.5 // second

    return Signal { observer in
      Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
        guard let self else { return }
        // カウントダウン
        limitSecond -= interval

        if !self.containsCurrentContentRect(in: tableView, at: indexPath) {
          timer.invalidate()
        }
        if limitSecond <= 0 {
          print("testing___check", indexPath)
          observer.receive(indexPath)
          timer.invalidate()
        }
      }
      return NonDisposable.instance
    }
  }
}

// MARK: - Configuration
extension TableViewImpressionTracker {
  struct Configuration {
    let trackingCellHeightRetio: Double
    let trackingImpressionSecond: TimeInterval

    init(trackingCellHeightRetio: Double, trackingImpressionSeccond: TimeInterval) {
      self.trackingCellHeightRetio = min(1.0, trackingCellHeightRetio)
      self.trackingImpressionSecond = max(0.0, trackingImpressionSeccond)
    }

    static var `default`: Configuration {
      Configuration(trackingCellHeightRetio: 2/3, trackingImpressionSeccond: 2.0)
    }
  }
}
