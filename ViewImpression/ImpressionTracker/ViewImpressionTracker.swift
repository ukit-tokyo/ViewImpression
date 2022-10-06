//
//  ViewImpressionTracker.swift
//  ViewImpression
//
//  Created by Taichi Yuki on 2022/10/04.
//

import UIKit
import ReactiveKit
import Bond

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
  private let indexPathsForTracking = Observable<[IndexPath]>([])
  var trackingIndexPaths: Signal<[IndexPath], Never> {
    indexPathsForTracking.toSignal()
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
      .flatMap(.latest) { _ in
        // offset 変化時に画面表示中の Cell の index を全て取得
        indexPathsForVisibleRows
      }
      .compactMap { $0 }
      .map { [unowned self] visibleIndexPaths in
        // 画面表示中の Cell の内、計測対象の閾値を満たす Cell の Index にフィルタ
        let tableViewContentRect = CGRect(
          x: tableView.contentOffset.x,
          y: tableView.contentOffset.y,
          width: tableView.bounds.width,
          height: tableView.bounds.height
        )

        return visibleIndexPaths.filter { indexPath in
          guard let cell = tableView.cellForRow(at: indexPath) else { return false }
          let cellRect = cell.contentView.convert(cell.contentView.bounds, to: tableView)
          let thresholdPoints = self.getThresholdPoints(from: cellRect)

          return tableViewContentRect.contains(thresholdPoints.topPoint)
            && tableViewContentRect.contains(thresholdPoints.bottomPoint)
        }
      }
      .removeDuplicates()
      .map { [unowned self] trackingIndexPaths in
        // 既に表示済み（計測済み）の Cell の Index を除外することで重複して計測されるのを防ぐ
        let filteredIndexPaths = trackingIndexPaths.filter { indexPath in
          !self.trackedIndexPaths.contains(indexPath)
        }
        self.cacheTrackedIndexPath(filteredIndexPaths)
        return filteredIndexPaths
      }
      .bind(to: indexPathsForTracking)
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

  /// 計測済みの Cell の Index をキャッシュする
  private func cacheTrackedIndexPath(_ indexPaths: [IndexPath]) {
    indexPaths.forEach { indexPath in
      trackedIndexPaths.insert(indexPath)
    }
  }
}

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
