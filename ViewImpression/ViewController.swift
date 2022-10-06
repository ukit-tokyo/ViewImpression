//
//  ViewController.swift
//  ViewImpression
//
//  Created by Taichi Yuki on 2022/10/04.
//

import UIKit

class ViewController: UIViewController, TableViewImpressionTrackable {
  let tableView = UITableView()
  let impressionTracker = TableViewImpressionTracker()

  override func viewDidLoad() {
    super.viewDidLoad()

    setupImpressionTracker()
    impressionTracker.trackingIndexPaths
      .bind(to: self) { me, indexPaths  in
        print("testing___indexPaths", indexPaths)
      }

    tableView.dataSource = self
    tableView.register(Cell.self, forCellReuseIdentifier: "Cell")

    view.addSubview(tableView)
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
    tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
  }
}

extension ViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 20
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! Cell
    cell.label.text = "Row : \(indexPath.row)"
    return cell
  }
}

final class Cell: UITableViewCell {
  lazy var label: UILabel = {
    let label = UILabel()
    label.textColor = .label
    label.font = .boldSystemFont(ofSize: 30)
    label.textAlignment = .center
    return label
  }()

  private lazy var separator: UIView = {
    let view = UIView()
    view.backgroundColor = .gray
    return view
  }()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    contentView.backgroundColor = .systemBackground
    contentView.addSubview(label)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
    label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
    label.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
    label.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
    label.heightAnchor.constraint(equalToConstant: 300).isActive = true

    contentView.addSubview(separator)
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
    separator.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
    separator.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
    separator.heightAnchor.constraint(equalToConstant: 2).isActive = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

