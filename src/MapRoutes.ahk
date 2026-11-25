; ==============================================================================
; WAYSTONE-INDEXED TRANSIT ROUTES (0 = ELDORIA HUB, 1..30 = WAYSTONES #1..#30)
;   Aligned to public/maps/map_area & public/maps/top_label (WS0..WS30)
;   gx/gy = world grid coords (West=-x, East=+x, North=-y, South=+y)
; ==============================================================================

waystoneRoutes := Map(
    0, {
        label: "WS #0: Eldoria Hub",
        file: "WS0_Eldoria.png",
        gx: 0, gy: 0,
        toNext: [{keys: ["a"], ms: 156}, {keys: ["w", "a"], ms: 875}, {keys: ["a"], ms: 3438}, {keys: ["a", "s"], ms: 78}, {keys: ["a"], ms: 3719}, {keys: ["a", "s"], ms: 78}, {keys: ["a"], ms: 1500}]
    },
    1, {
        label: "WS #1: Whisperwood",
        file: "WS1_Whisperwood.png",
        gx: -1, gy: 0,
        toNext: [{keys: ["w"], ms: 1235}, {keys: ["w", "d"], ms: 62}, {keys: ["w"], ms: 1110}, {keys: ["w", "a"], ms: 78}, {keys: ["w"], ms: 5828}]
    },
    2, {
        label: "WS #2: Elderwood Deep",
        file: "WS2_Elderwood_Deep.png",
        gx: -1, gy: -1,
        toNext: [{keys: ["d"], ms: 4438}, {keys: ["s", "d"], ms: 62}, {keys: ["d"], ms: 1828}, {keys: ["s", "d"], ms: 63}, {keys: ["d"], ms: 2375}]
    },
    3, {
        label: "WS #3: Mirewood Bog",
        file: "WS3_Mirewood_Bog.png",
        gx: 0, gy: -1,
        toNext: [{keys: ["d"], ms: 4468}, {keys: ["s", "d"], ms: 219}, {keys: ["d"], ms: 188}, {keys: ["w", "d"], ms: 234}, {keys: ["d"], ms: 219}, {keys: ["s", "d"], ms: 281}, {keys: ["d"], ms: 406}, {keys: ["w", "d"], ms: 125}, {keys: ["d"], ms: 2203}, {keys: ["w", "d"], ms: 63}, {keys: ["d"], ms: 656}]
    },
    4, {
        label: "WS #4: Sunscar Oasis",
        file: "WS4_Sunscar_Oasis.png",
        gx: 1, gy: -1,
        toNext: [{keys: ["s"], ms: 94}, {keys: ["s", "d"], ms: 141}, {keys: ["s"], ms: 8499}]
    },
    5, {
        label: "WS #5: Dunes of Khar",
        file: "WS5_Dunes_of_Khar.png",
        gx: 1, gy: 0,
        toNext: [{keys: ["s"], ms: 5375}, {keys: ["a", "s"], ms: 1704}, {keys: ["s"], ms: 328}, {keys: ["a", "s"], ms: 281}, {keys: ["s"], ms: 172}, {keys: ["a", "s"], ms: 62}, {keys: ["s"], ms: 157}, {keys: ["a", "s"], ms: 78}, {keys: ["s"], ms: 62}, {keys: ["a", "s"], ms: 94}, {keys: ["s"], ms: 219}, {keys: ["a", "s"], ms: 62}, {keys: ["s"], ms: 500}, {keys: ["s", "d"], ms: 110}]
    },
    6, {
        label: "WS #6: Emberfall Caldera",
        file: "WS6_Emberfall_Caldera.png",
        gx: 1, gy: 1,
        toNext: [{keys: ["a"], ms: 3969}, {keys: ["a", "s"], ms: 78}, {keys: ["a"], ms: 3656}, {keys: ["w", "a"], ms: 78}, {keys: ["a"], ms: 1078}]
    },
    7, {
        label: "WS #7: Fallen Outskirts",
        file: "WS7_FallenOutskirts.png",
        gx: 0, gy: 1,
        toNext: [{keys: ["a"], ms: 234}, {keys: ["a", "s"], ms: 157}, {keys: ["a"], ms: 1921}, {keys: ["w", "a"], ms: 79}, {keys: ["a"], ms: 984}, {keys: ["a", "s"], ms: 62}, {keys: ["a"], ms: 469}, {keys: ["a", "s"], ms: 63}, {keys: ["a"], ms: 4547}]
    },
    8, {
        label: "WS #8: Ashen Ruins",
        file: "WS8_Ashen_Ruins.png",
        gx: -1, gy: 1,
        toNext: [{keys: ["a", "s"], ms: 297}, {keys: ["a"], ms: 375}, {keys: ["w", "a"], ms: 125}, {keys: ["a"], ms: 625}, {keys: ["w", "a"], ms: 63}, {keys: ["a"], ms: 437}, {keys: ["w", "a"], ms: 110}, {keys: ["a"], ms: 343}, {keys: ["w", "a"], ms: 172}, {keys: ["a"], ms: 1047}, {keys: ["a", "s"], ms: 156}, {keys: ["a"], ms: 2969}, {keys: ["a", "s"], ms: 78}, {keys: ["a"], ms: 1907}, {keys: ["w", "a"], ms: 78}, {keys: ["a"], ms: 140}]
    },
    9, {
        label: "WS #9: Varn Necropolis",
        file: "WS9_Varn_Necropolis.png",
        gx: -2, gy: 1,
        toNext: [{keys: ["w"], ms: 2266}, {keys: ["w", "a"], ms: 78}, {keys: ["w"], ms: 1484}, {keys: ["w", "d"], ms: 79}, {keys: ["w"], ms: 4734}]
    },
    10, {
        label: "WS #10: Abyssal Rift",
        file: "WS10_Abyssal_Rift.png",
        gx: -2, gy: 0,
        toNext: [{keys: ["w"], ms: 2641}, {keys: ["w", "a"], ms: 63}, {keys: ["w"], ms: 1250}, {keys: ["w", "d"], ms: 62}, {keys: ["w"], ms: 1844}, {keys: ["w", "d"], ms: 62}, {keys: ["w"], ms: 1438}, {keys: ["w", "d"], ms: 94}, {keys: ["w"], ms: 484}, {keys: ["w", "a"], ms: 109}, {keys: ["w"], ms: 828}]
    },
    11, {
        label: "WS #11: Frostvale Hills",
        file: "WS11_Frostvale_Hills.png",
        gx: -2, gy: -1,
        toNext: [{keys: ["d"], ms: 109}, {keys: ["a"], ms: 63}, {keys: ["d"], ms: 562}, {keys: ["s", "d"], ms: 63}, {keys: ["d"], ms: 296}, {keys: ["w", "a"], ms: 765}, {keys: ["w"], ms: 110}, {keys: ["w", "a"], ms: 687}, {keys: ["w"], ms: 875}, {keys: ["w", "d"], ms: 78}, {keys: ["w"], ms: 438}, {keys: ["w", "a"], ms: 78}, {keys: ["w"], ms: 937}, {keys: ["w", "a"], ms: 110}, {keys: ["w"], ms: 4094}, {keys: ["w", "a"], ms: 93}, {keys: ["w"], ms: 641}]
    },
    12, {
        label: "WS #12: Glacier Pass",
        file: "WS12_Glacier_Pass.png",
        gx: -2, gy: -2,
        toNext: [{keys: ["d"], ms: 813}, {keys: ["s", "d"], ms: 94}, {keys: ["d"], ms: 7766}]
    },
    13, {
        label: "WS #13: Crown of Winter",
        file: "WS13_Crown_of_Winter.png",
        gx: -1, gy: -2,
        toNext: [{keys: ["d"], ms: 6610}, {keys: ["w", "d"], ms: 2312}, {keys: ["d"], ms: 188}, {keys: ["w", "d"], ms: 312}, {keys: ["d"], ms: 94}]
    },
    14, {
        label: "WS #14: Skyreach Spires",
        file: "WS14_Skyreach_Spires.png",
        gx: 0, gy: -2,
        toNext: [{keys: ["d"], ms: 531}, {keys: ["s", "d"], ms: 563}, {keys: ["d"], ms: 218}, {keys: ["s", "d"], ms: 79}, {keys: ["d"], ms: 125}, {keys: ["s", "d"], ms: 78}, {keys: ["d"], ms: 156}, {keys: ["s", "d"], ms: 62}, {keys: ["d"], ms: 516}, {keys: ["s", "d"], ms: 313}, {keys: ["d"], ms: 234}, {keys: ["s", "d"], ms: 312}, {keys: ["d"], ms: 344}, {keys: ["s", "d"], ms: 328}, {keys: ["d"], ms: 344}, {keys: ["s", "d"], ms: 359}, {keys: ["d"], ms: 375}, {keys: ["s", "d"], ms: 79}, {keys: ["d"], ms: 296}, {keys: ["s", "d"], ms: 79}, {keys: ["d"], ms: 265}, {keys: ["s", "d"], ms: 94}, {keys: ["d"], ms: 594}, {keys: ["w", "d"], ms: 125}, {keys: ["d"], ms: 265}, {keys: ["w", "d"], ms: 94}, {keys: ["d"], ms: 734}, {keys: ["w", "d"], ms: 94}, {keys: ["d"], ms: 1563}]
    },
    15, {
        label: "WS #15: Blightwood Wastes",
        file: "WS15_Blightwood_Wastes.png",
        gx: 1, gy: -2,
        toNext: [{keys: ["d"], ms: 641}, {keys: ["s", "d"], ms: 78}, {keys: ["d"], ms: 7937}]
    },
    16, {
        label: "WS #16: Bonebleach Barrens",
        file: "WS16_Bonebleach_Barrens.png",
        gx: 2, gy: -2,
        toNext: [{keys: ["s"], ms: 2797}, {keys: ["s", "d"], ms: 78}, {keys: ["s"], ms: 938}, {keys: ["s", "d"], ms: 62}, {keys: ["s"], ms: 4266}, {keys: ["s", "d"], ms: 62}, {keys: ["s"], ms: 578}]
    },
    17, {
        label: "WS #17: Shardglow Caverns",
        file: "WS17_Shardglow_Caverns.png",
        gx: 2, gy: -1,
        toNext: [{keys: ["s"], ms: 3641}, {keys: ["s", "d"], ms: 109}, {keys: ["s"], ms: 2328}, {keys: ["a", "s"], ms: 94}, {keys: ["s"], ms: 813}, {keys: ["s", "d"], ms: 78}, {keys: ["s"], ms: 609}, {keys: ["s", "d"], ms: 78}, {keys: ["s"], ms: 953}]
    },
    18, {
        label: "WS #18: Starfall Isles",
        file: "WS18_Starfall_Isles.png",
        gx: 2, gy: 0,
        toNext: [{keys: ["s"], ms: 579}, {keys: ["a", "s"], ms: 46}, {keys: ["s"], ms: 579}, {keys: ["a", "s"], ms: 78}, {keys: ["s"], ms: 2265}, {keys: ["s", "d"], ms: 141}, {keys: ["s"], ms: 2031}, {keys: ["a", "s"], ms: 453}, {keys: ["s"], ms: 594}, {keys: ["a", "s"], ms: 328}, {keys: ["s"], ms: 281}, {keys: ["a", "s"], ms: 235}, {keys: ["s"], ms: 234}, {keys: ["a", "s"], ms: 219}, {keys: ["s"], ms: 250}, {keys: ["a", "s"], ms: 1078}, {keys: ["s"], ms: 156}, {keys: ["s", "d"], ms: 110}]
    },
    19, {
        label: "WS #19: Coralhollow Reef",
        file: "WS19_Coralhollow_Reef.png",
        gx: 2, gy: 1,
        toNext: [{keys: ["s", "d"], ms: 531}, {keys: ["s"], ms: 1140}, {keys: ["s", "d"], ms: 454}, {keys: ["s"], ms: 328}, {keys: ["s", "d"], ms: 140}, {keys: ["s"], ms: 312}, {keys: ["s", "d"], ms: 360}, {keys: ["s"], ms: 437}, {keys: ["s", "d"], ms: 282}, {keys: ["s"], ms: 343}, {keys: ["s", "d"], ms: 313}, {keys: ["s"], ms: 515}, {keys: ["s", "d"], ms: 297}, {keys: ["s"], ms: 235}, {keys: ["s", "d"], ms: 234}, {keys: ["s"], ms: 625}, {keys: ["a", "s"], ms: 469}, {keys: ["s"], ms: 515}, {keys: ["a", "s"], ms: 579}, {keys: ["s"], ms: 281}, {keys: ["a", "s"], ms: 562}, {keys: ["s"], ms: 343}, {keys: ["a", "s"], ms: 672}, {keys: ["s"], ms: 406}]
    },
    20, {
        label: "WS #20: Ashveil Badlands",
        file: "WS20_Ashveil_Badlands.png",
        gx: 2, gy: 2,
        toNext: [{keys: ["a"], ms: 4032}, {keys: ["a", "s"], ms: 78}, {keys: ["a"], ms: 1859}, {keys: ["w", "a"], ms: 1750}, {keys: ["a"], ms: 578}, {keys: ["w", "a"], ms: 500}, {keys: ["a"], ms: 531}]
    },
    21, {
        label: "WS #21: The Crimson Deep",
        file: "WS21_The_Crimson_Deep.png",
        gx: 1, gy: 2,
        toNext: [{keys: ["a"], ms: 234}, {keys: ["a", "s"], ms: 750}, {keys: ["a"], ms: 594}, {keys: ["a", "s"], ms: 344}, {keys: ["a"], ms: 203}, {keys: ["a", "s"], ms: 141}, {keys: ["a"], ms: 250}, {keys: ["a", "s"], ms: 47}, {keys: ["a"], ms: 421}, {keys: ["a", "s"], ms: 157}, {keys: ["a"], ms: 218}, {keys: ["a", "s"], ms: 157}, {keys: ["a"], ms: 140}, {keys: ["a", "s"], ms: 219}, {keys: ["a"], ms: 156}, {keys: ["a", "s"], ms: 172}, {keys: ["a"], ms: 235}, {keys: ["a", "s"], ms: 93}, {keys: ["a"], ms: 203}, {keys: ["a", "s"], ms: 94}, {keys: ["a"], ms: 110}, {keys: ["a", "s"], ms: 140}, {keys: ["a"], ms: 172}, {keys: ["a", "s"], ms: 94}, {keys: ["a"], ms: 1890}, {keys: ["w", "a"], ms: 282}, {keys: ["w"], ms: 547}, {keys: ["w", "a"], ms: 1093}, {keys: ["a"], ms: 563}, {keys: ["w", "a"], ms: 172}, {keys: ["a"], ms: 437}]
    },
    22, {
        label: "WS #22: Rimeveil Abyss",
        file: "WS22_Rimeveil_Abyss.png",
        gx: 0, gy: 2,
        toNext: [{keys: ["a", "s"], ms: 500}, {keys: ["a"], ms: 734}, {keys: ["a", "s"], ms: 688}, {keys: ["a"], ms: 562}, {keys: ["a", "s"], ms: 156}, {keys: ["a"], ms: 250}, {keys: ["a", "s"], ms: 47}, {keys: ["a"], ms: 688}, {keys: ["a", "s"], ms: 125}, {keys: ["a"], ms: 187}, {keys: ["a", "s"], ms: 344}, {keys: ["a"], ms: 234}, {keys: ["a", "s"], ms: 172}, {keys: ["a"], ms: 235}, {keys: ["a", "s"], ms: 156}, {keys: ["a"], ms: 266}, {keys: ["a", "s"], ms: 156}, {keys: ["a"], ms: 156}, {keys: ["a", "s"], ms: 172}, {keys: ["a"], ms: 578}, {keys: ["w", "a"], ms: 110}, {keys: ["a"], ms: 984}, {keys: ["w", "a"], ms: 94}, {keys: ["a"], ms: 390}, {keys: ["w", "a"], ms: 141}, {keys: ["a"], ms: 1375}]
    },
    23, {
        label: "WS #23: Glimmerfen Hollows",
        file: "WS23_Glimmerfen_Hollows.png",
        gx: -1, gy: 2,
        toNext: [{keys: ["a"], ms: 2250}, {keys: ["w", "a"], ms: 125}, {keys: ["a"], ms: 578}, {keys: ["a", "s"], ms: 94}, {keys: ["a"], ms: 390}, {keys: ["w", "a"], ms: 63}, {keys: ["a"], ms: 5328}]
    },
    24, {
        label: "WS #24: The Sunforge",
        file: "WS24_The_Sunforge.png",
        gx: -2, gy: 2,
        toNext: [{keys: ["a", "s"], ms: 1109}, {keys: ["s"], ms: 1578}, {keys: ["s", "d"], ms: 110}, {keys: ["s"], ms: 437}, {keys: ["s", "d"], ms: 297}, {keys: ["s"], ms: 1031}, {keys: ["s", "d"], ms: 125}, {keys: ["s"], ms: 1375}, {keys: ["a", "s"], ms: 188}, {keys: ["s"], ms: 1359}, {keys: ["a", "s"], ms: 703}, {keys: ["s"], ms: 297}, {keys: ["a", "s"], ms: 453}, {keys: ["s"], ms: 266}, {keys: ["a", "s"], ms: 297}, {keys: ["s"], ms: 266}, {keys: ["a", "s"], ms: 281}, {keys: ["s"], ms: 187}, {keys: ["a", "s"], ms: 344}]
    },
    25, {
        label: "WS #25: Drumfield Carnival",
        file: "WS25_Drumfield_Carnival.png",
        gx: -2, gy: 3,
        toNext: [{keys: ["s"], ms: 2922}, {keys: ["s", "d"], ms: 78}, {keys: ["s"], ms: 2641}, {keys: ["a", "s"], ms: 1250}, {keys: ["s"], ms: 906}, {keys: ["a", "s"], ms: 844}, {keys: ["s"], ms: 765}, {keys: ["a", "s"], ms: 63}]
    },
    26, {
        label: "WS #26: Candlewax Abbey",
        file: "WS26_Candlewax_Abbey.png",
        gx: -2, gy: 4,
        toNext: [{keys: ["d"], ms: 219}, {keys: ["s", "d"], ms: 109}, {keys: ["d"], ms: 3953}, {keys: ["w", "d"], ms: 94}, {keys: ["d"], ms: 4140}]
    },
    27, {
        label: "WS #27: Toppled Gameboard",
        file: "WS27_Toppled_Gameboard.png",
        gx: -1, gy: 4,
        toNext: [{keys: ["d"], ms: 672}, {keys: ["s", "d"], ms: 94}, {keys: ["d"], ms: 156}, {keys: ["w"], ms: 359}, {keys: ["w", "d"], ms: 47}, {keys: ["d"], ms: 672}, {keys: ["s", "d"], ms: 328}, {keys: ["d"], ms: 1594}, {keys: ["s", "d"], ms: 94}, {keys: ["d"], ms: 734}, {keys: ["s", "d"], ms: 78}, {keys: ["d"], ms: 4250}]
    },
    28, {
        label: "WS #28: Gilded Glass Palace",
        file: "WS28_Gilded_Glass_Palace.png",
        gx: 0, gy: 4,
        toNext: [{keys: ["d"], ms: 1859}, {keys: ["w", "d"], ms: 359}, {keys: ["d"], ms: 532}, {keys: ["s", "d"], ms: 281}, {keys: ["d"], ms: 500}, {keys: ["s", "d"], ms: 125}, {keys: ["d"], ms: 265}, {keys: ["s", "d"], ms: 125}, {keys: ["d"], ms: 313}, {keys: ["s", "d"], ms: 94}, {keys: ["d"], ms: 2218}, {keys: ["s", "d"], ms: 79}, {keys: ["d"], ms: 1312}, {keys: ["s", "d"], ms: 125}, {keys: ["d"], ms: 313}, {keys: ["s", "d"], ms: 109}, {keys: ["d"], ms: 250}]
    },
    29, {
        label: "WS #29: Mossbound Tribunal",
        file: "WS29_Mossbound_Tribunal.png",
        gx: 1, gy: 4,
        toNext: [{keys: ["d"], ms: 2547}, {keys: ["w", "d"], ms: 172}, {keys: ["d"], ms: 266}, {keys: ["w", "d"], ms: 125}, {keys: ["d"], ms: 3703}, {keys: ["w", "d"], ms: 62}, {keys: ["d"], ms: 1125}, {keys: ["w", "d"], ms: 266}, {keys: ["d"], ms: 344}, {keys: ["s", "d"], ms: 437}, {keys: ["d"], ms: 47}]
    },
    30, {
        label: "WS #30: Duskhollow of Lost Things",
        file: "WS30_Duskhollow_of_Lost_Things.png",
        gx: 2, gy: 4,
        toNext: []
    }
)

GetFriendRouteLegs(fromIdx, toIdx) {
    global waystoneRoutes
    legs := []
    if (toIdx = fromIdx + 1) {
        if !waystoneRoutes.Has(fromIdx)
            return legs
        for l in waystoneRoutes[fromIdx].toNext
            legs.Push({keys: l.keys.Clone(), ms: l.ms})
        return legs
    }
    if (toIdx = fromIdx - 1) {
        if !waystoneRoutes.Has(toIdx)
            return legs
        raw := waystoneRoutes[toIdx].toNext
        i := raw.Length
        while (i >= 1) {
            legs.Push({keys: GetOppositeKeys(raw[i].keys), ms: raw[i].ms})
            i -= 1
        }
        return legs
    }
    return legs
}

GetActiveRouteLegs(fromIdx, toIdx, &sourceTag := "") {
    global shortestRoutes
    key := fromIdx "->" toIdx
    if (shortestRoutes.Has(key) && shortestRoutes[key].Length > 0) {
        sourceTag := "Shortest"
        cloned := []
        for l in shortestRoutes[key]
            cloned.Push({keys: l.keys.Clone(), ms: l.ms})
        return cloned
    }
    sourceTag := "Friend"
    return GetFriendRouteLegs(fromIdx, toIdx)
}

GetRouteTotalMs(legs) {
    total := 0
    for l in legs
        total += l.ms
    return total
}

ComputeLegsNetVector(legs) {
    dx := 0.0
    dy := 0.0
    for l in legs {
        factor := (l.keys.Length > 1) ? 0.7071 : 1.0
        delta  := l.ms * factor
        for k in l.keys {
            if (k = "w")
                dy -= delta
            else if (k = "s")
                dy += delta
            else if (k = "a")
                dx -= delta
            else if (k = "d")
                dx += delta
        }
    }
    return {dx: dx, dy: dy}
}