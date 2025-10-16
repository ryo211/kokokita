//
//  HomeFilterHeader.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/30.
//

// HomeFilterHeader.swift（新規）
import SwiftUI
import MapKit

struct HomeFilterHeader: View {
    @ObservedObject var vm: HomeViewModel
    var onTapSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                // ロゴ
                KokokitaHeaderLogoSimple()

                Spacer()

                // 検索ボタン
                Button(action: onTapSearch) {
                    Image(systemName: "magnifyingglass").font(.title2)
                        .foregroundStyle(Color.blue)
                }
                .buttonStyle(.plain)
                
                Button {
                    vm.toggleSort()
                } label: {
                    // 降順（最新が上）がデフォ。アイコンと説明を状態で出し分け。
                    HStack(spacing: 6) {
                        Text(vm.sortAscending ? "　古い順" : "新しい順")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: vm.sortAscending ? "chevron.up"
                                                           : "chevron.down")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
            }

            // 1) キーワード
            if !vm.titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                FlowRow(spacing: 6, rowSpacing: 6) {
                    Chip(vm.titleQuery, kind: .keyword) {
                        vm.titleQuery = ""
                        vm.reload()
                    }
                }
            }

            // 2) 期間
            if vm.dateFrom != nil || vm.dateTo != nil {
                let label = dateRangeText(from: vm.dateFrom, to: vm.dateTo)
                FlowRow(spacing: 6, rowSpacing: 6) {
                    Chip(label, kind: .period) {
                        vm.dateFrom = nil; vm.dateTo = nil
                        vm.reload()
                    }
                }
            }

            // 3) ラベル（単一）
            if let lid = vm.labelFilter {
                let lmap = Dictionary(uniqueKeysWithValues: vm.labels.map { ($0.id, $0.name) })
                let name = (lmap[lid] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                FlowRow(spacing: 6, rowSpacing: 6) {
                    Chip(name, kind: .label) {
                        vm.labelFilter = nil
                        vm.reload()
                    }
                }
            }

            // 4) グループ（単一）
            if let gid = vm.groupFilter {
                let gmap = Dictionary(uniqueKeysWithValues: vm.groups.map { ($0.id, $0.name) })
                let name = (gmap[gid] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                FlowRow(spacing: 6, rowSpacing: 6) {
                    Chip(name, kind: .group) {
                        vm.groupFilter = nil
                        vm.reload()
                    }
                }
            }

            // 5) メンバー（単一）
            if let mid = vm.memberFilter {
                let mmap = Dictionary(uniqueKeysWithValues: vm.members.map { ($0.id, $0.name) })
                let name = (mmap[mid] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                FlowRow(spacing: 6, rowSpacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "person")
                            .font(.caption2)
                        Text(name)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            vm.memberFilter = nil
                            vm.reload()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }

            // 6) カテゴリ
            if let catRaw = vm.categoryFilter {
                let category = MKPointOfInterestCategory(rawValue: catRaw)
                let name = category.japaneseName
                FlowRow(spacing: 6, rowSpacing: 6) {
                    Chip(name, kind: .category) {
                        vm.categoryFilter = nil
                        vm.reload()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private func dateRangeText(from: Date?, to: Date?) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        switch (from, to) {
        case let (fD?, tD?): return "\(f.string(from: fD)) 〜 \(f.string(from: tD))"
        case let (fD?, nil): return "\(f.string(from: fD)) 〜"
        case let (nil, tD?): return "〜 \(f.string(from: tD))"
        default: return ""
        }
    }
}
