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
    // contentOffset の変化を監視
    tableView.reactive.keyPath(\.contentOffset)
      // offset が変化した時に画面に表示されてるの Cell の index を全て取得
      .flatMap(.latest) { _ in indexPathsForVisibleRows }
      .compactMap { $0 }
      // 画面に表示中の Cell の内、計測対象の閾値を満たす Cell の Index にフィルタ
      .map { visibleIndexPaths in
        let tableViewContentRect = CGRect(
          x: tableView.contentOffset.x,
          y: tableView.contentOffset.y,
          width: tableView.bounds.width,
          height: tableView.bounds.height
        )

        return visibleIndexPaths.filter { [unowned self] indexPath in
          guard let cell = tableView.cellForRow(at: indexPath) else { return false }
          let cellRect = cell.contentView.convert(cell.contentView.bounds, to: tableView)
          let thresholdPoints = self.getThresholdPoints(from: cellRect)

          return tableViewContentRect.contains(thresholdPoints.topPoint)
            && tableViewContentRect.contains(thresholdPoints.bottomPoint)
        }
      }
      .removeDuplicates()
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
}

extension TableViewImpressionTracker {
  struct Configuration {
    let trackingCellHeightRetio: Double
    let trackingImpressionSeccond: Double

    init(trackingCellHeightRetio: Double, trackingImpressionSeccond: Double) {
      guard trackingCellHeightRetio <= 1 else {
        fatalError("`trackingCellHeightRetio` must be less than or equal to 1")
      }
      self.trackingCellHeightRetio = trackingCellHeightRetio
      self.trackingImpressionSeccond = trackingImpressionSeccond
    }

    static var `default`: Configuration {
      Configuration(trackingCellHeightRetio: 2/3, trackingImpressionSeccond: 2)
    }
  }
}
