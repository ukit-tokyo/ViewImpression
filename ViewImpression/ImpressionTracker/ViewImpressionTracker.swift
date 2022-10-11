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
  var indexPathForTrackingImpression: Signal<IndexPath, Never> {
    impressionTracker.trackingIndexPath
  }

  func setupImpressionTracker() {
    impressionTracker.setup(with: tableView)
  }

  func startImpressionTracking() {
    impressionTracker.startTracking()
  }

  func stopImpressionTracking() {
    impressionTracker.stopTracking()
  }

  func restartImpressionTracking() {
    impressionTracker.restartTracking()
  }
}

// MARK: - TableViewImpressionTracker
final class TableViewImpressionTracker {
  private struct ThresholdPoints {
    let topPoint: CGPoint
    let bottomPoint: CGPoint
  }

  private let config: Configuration
  private var trackedIndexPaths: Set<IndexPath> = []
  private let trackable = Observable<Bool>(false)
  private let indexPathForTracking = Subject<IndexPath?, Never>()
  var trackingIndexPath: Signal<IndexPath, Never> {
    indexPathForTracking.ignoreNils().toSignal()
  }

  init(config: Configuration = .default) {
    self.config = config
  }

  func setup(with tableView: UITableView) {
    bind(tableView: tableView)
  }
  /// インプレッション計測開始
  func startTracking() {
    trackable.send(true)
  }
  /// インプレッション計測停止
  func stopTracking() {
    trackable.send(false)
  }
  /// インプレッション計測のリセット
  /// 計測済みのCellのIndexキャッシュを削除し、再度計測を開始する
  func restartTracking() {
    trackedIndexPaths.removeAll()
    indexPathForTracking.send(nil)
    startTracking()
  }

  private func bind(tableView: UITableView) {
    let indexPathsForVisibleRows = tableView.reactive.keyPath(\.indexPathsForVisibleRows)
    let indexPath = tableView.reactive.keyPath(\.contentOffset) // contentOffset の変化を監視
      .flatMapLatest { _ in
        // offset 変化時に画面表示中の Cell の index を全て取得
        indexPathsForVisibleRows
      }
      .ignoreNils()
      .flattenElements()
      .filter { [unowned self] visibleIndexPath in
        // 画面表示中の Cell のうち、計測対象の閾値を満たす Cell の Index に絞る
        self.containsCurrentContentRect(in: tableView, at: visibleIndexPath)
      }
      .removeDuplicates()
      .flatMapMerge { [unowned self] trackingIndexPath in
        // 指定秒間対象IndexのCellが表示され続けたことを評価する
        self.filterContinuousDisplayedIndex(in: tableView, at: trackingIndexPath)
      }
      .filter { [unowned self] trackingIndexPath in
        /// 一度表示（計測）された Cell の Index はキャッシュして、重複してイベントを流さない
        if self.trackedIndexPaths.contains(trackingIndexPath) { return false }
        self.trackedIndexPaths.insert(trackingIndexPath)
        return true
      }

    // `trackable` フラグが立っている時だけ計測する
    combineLatest(trackable, indexPath)
      .filter { trackable, _ in trackable }
      .map { _, indexPath in indexPath }
      .removeDuplicates() // trackable フラグを変えた瞬間に、最後に計測したindexが流れてしまうのを防ぐ
      .bind(to: indexPathForTracking)
  }

  /// 評価対象のCellのframeから、計測対象の閾値となる座標を割り出す
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

    let cellRect = tableView.rectForRow(at: indexPath)
    guard cellRect != .zero else { return false }
    let thresholdPoints = getThresholdPoints(from: cellRect)

    return tableViewCurrentContentRect.contains(thresholdPoints.topPoint)
      && tableViewCurrentContentRect.contains(thresholdPoints.bottomPoint)
  }

  /// 評価対象のCellのIndexが、n秒間表示され続けたかを0.5秒間隔でチェックする
  private func filterContinuousDisplayedIndex(in tableView: UITableView, at indexPath: IndexPath) ->  Signal<IndexPath, Never> {
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
