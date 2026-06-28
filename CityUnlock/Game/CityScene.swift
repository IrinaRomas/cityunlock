import SpriteKit
import CoreLocation

class CityScene: SKScene {

    // MARK: - Properties
    
    var currentCity: City?

    var roads: [[CLLocationCoordinate2D]] = [] {
        didSet { rebuildScene() }
    }

    var buildings: [Building] = [] {
        didSet { rebuildScene() }
    }

    var onBuildingTapped: ((Building) -> Void)?

    private var converter: IsoConverter?
    private var buildingNodes: [String: SKNode] = [:]
    private var cameraNode = SKCameraNode()

    // Pan/zoom gesture state
    private var lastPanLocation: CGPoint?

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.29, green: 0.54, blue: 0.18, alpha: 1)
        if cameraNode.parent == nil { addChild(cameraNode) }
        camera = cameraNode
        cameraNode.xScale = 1.0
        cameraNode.yScale = 1.0
        setupGestures(in: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        print("🔄 didChangeSize: \(oldSize) → \(size), buildings=\(buildings.count), city=\(currentCity?.name ?? "nil")")
        guard size.width > 0, size.height > 0 else { return }
        if let city = currentCity {
            converter = IsoConverter(city: city, sceneSize: size)
        }
        rebuildScene()
    }
    
    private func setupGestures(in view: SKView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        view.addGestureRecognizer(pinch)
    }

    // MARK: - Scene Building

    func configure(with city: City) {
        currentCity = city
        converter = IsoConverter(city: city, sceneSize: size)
    }

    private func rebuildScene() {
        print("🏗 rebuildScene: зданий=\(buildings.count), converter=\(converter != nil), size=\(size)")
        
        // Remove old building nodes
        buildingNodes.values.forEach { $0.removeFromParent() }
        buildingNodes.removeAll()

        drawGround()

        // Sort buildings by Y position for correct iso draw order
        let sorted = buildings.sorted { b1, b2 in
            avgLat(b1) > avgLat(b2)
        }
        
        guard let conv = converter else { return }

        drawRoads(conv: conv)

        for building in sorted {
            let node = buildingNode(for: building)
            addChild(node)
            buildingNodes[building.id] = node
        }
        
        // Position camera at city center and fit all buildings in view
        let validPositions = buildingNodes.values
            .filter { !$0.children.isEmpty }
            .map { $0.position }
        print("📍 validPositions count=\(validPositions.count), size=\(size)")

        if !validPositions.isEmpty {
            let xs = validPositions.map(\.x).sorted()
            let ys = validPositions.map(\.y).sorted()
            let medX = xs[xs.count / 2]
            let medY = ys[ys.count / 2]
            cameraNode.position = CGPoint(x: medX, y: medY)
            print("📍 median center=\(cameraNode.position)")
        } else if let city = currentCity, let conv = converter {
            cameraNode.position = conv.isoPoint(lat: city.latitude, lon: city.longitude)
        }

        cameraNode.xScale = 1.0
        cameraNode.yScale = 1.0
    }

    private func drawRoads(conv: IsoConverter) {
        for roadCoords in roads {
            guard roadCoords.count >= 2 else { continue }
            let pts = conv.isoPoints(coords: roadCoords)
            let path = CGMutablePath()
            path.move(to: pts[0])
            for pt in pts.dropFirst() { path.addLine(to: pt) }

            let road = SKShapeNode(path: path)
            road.strokeColor = SKColor(white: 0.85, alpha: 0.9)
            road.lineWidth = 3
            road.lineCap = .round
            road.lineJoin = .round
            road.zPosition = -10
            addChild(road)
        }
    }

    private func drawGround() {
        guard converter != nil else { return }
        removeAllChildren()
        if cameraNode.parent == nil {
            addChild(cameraNode)
        }
        // Простой фон вместо тайловой сетки
        let bg = SKSpriteNode(color: SKColor(red: 0.35, green: 0.6, blue: 0.25, alpha: 1),
                              size: CGSize(width: 50000, height: 50000))
        bg.zPosition = -1000
        addChild(bg)
    }

    private func groundColor(row: Int, col: Int) -> SKColor {
        let v = (row + col) % 2 == 0 ? 0.42 : 0.45
        return SKColor(red: 0.25, green: CGFloat(v), blue: 0.18, alpha: 1)
    }

    // MARK: - Building Nodes

    private func buildingNode(for building: Building) -> SKNode {
        guard let conv = converter else { return SKNode() }

        let container = SKNode()
        container.name = building.id

        let coords = building.coordinates
        guard !coords.isEmpty else { return container }

        let isoPoints = conv.isoPoints(coords: coords)
        let center = conv.centroid(of: isoPoints)
        print("center: \(center)")
        container.position = center

        let scale = conv.buildingSize(areaM2: building.areaM2)
        let height = conv.buildingHeight(levels: building.levels)

        switch building.state {
        case .locked:
            addLockedBuilding(to: container, scale: scale, height: height, building: building, conv: conv)
        case .constructing:
            addConstructingBuilding(to: container, scale: scale, height: height, building: building)
        case .unlocked:
            addUnlockedBuilding(to: container, scale: scale, height: height, building: building)
        }
        
        print("center =", center)
        print("scale =", scale)
        
        print("Building \(building.displayName)")
        print("position =", container.position)
        print("children =", container.children.count)

        return container
    }

    private func addUnlockedBuilding(to node: SKNode, scale: CGFloat, height: CGFloat, building: Building) {
        let w = scale
        let h = scale * 0.5

        // Front face (left)
        let left = SKShapeNode()
        let leftPath = CGMutablePath()
        leftPath.move(to: CGPoint(x: -w/2, y: 0))
        leftPath.addLine(to: CGPoint(x: 0, y: h/2))
        leftPath.addLine(to: CGPoint(x: 0, y: h/2 + height))
        leftPath.addLine(to: CGPoint(x: -w/2, y: height))
        leftPath.closeSubpath()
        left.path = leftPath
        left.fillColor = wallColorLeft(building.type)
        left.strokeColor = SKColor(white: 0, alpha: 0.15)
        left.lineWidth = 0.5
        node.addChild(left)

        // Front face (right)
        let right = SKShapeNode()
        let rightPath = CGMutablePath()
        rightPath.move(to: CGPoint(x: 0, y: h/2))
        rightPath.addLine(to: CGPoint(x: w/2, y: 0))
        rightPath.addLine(to: CGPoint(x: w/2, y: height))
        rightPath.addLine(to: CGPoint(x: 0, y: h/2 + height))
        rightPath.closeSubpath()
        right.path = rightPath
        right.fillColor = wallColorRight(building.type)
        right.strokeColor = SKColor(white: 0, alpha: 0.15)
        right.lineWidth = 0.5
        node.addChild(right)

        // Roof
        let roof = SKShapeNode()
        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: -w/2, y: height))
        roofPath.addLine(to: CGPoint(x: 0, y: h/2 + height))
        roofPath.addLine(to: CGPoint(x: w/2, y: height))
        roofPath.addLine(to: CGPoint(x: 0, y: height - h/2))
        roofPath.closeSubpath()
        roof.path = roofPath
        roof.fillColor = roofColor(building.type)
        roof.strokeColor = SKColor(white: 0, alpha: 0.1)
        roof.lineWidth = 0.5
        node.addChild(roof)

        // Emoji + name label above building
        let emoji = SKLabelNode(text: building.type.emoji)
        emoji.fontSize = max(scale * 0.5, 8)
        emoji.verticalAlignmentMode = .bottom
        emoji.position = CGPoint(x: 0, y: height + 2)
        emoji.zPosition = 11
        node.addChild(emoji)

        let label = SKLabelNode(text: building.displayName)
        label.fontSize = 5
        label.fontColor = .white
        label.fontName = "Helvetica-Bold"
        label.position = CGPoint(x: 0, y: height + emoji.fontSize + 4)
        label.zPosition = 10
        node.addChild(label)

        node.zPosition = CGFloat(-node.position.y)
    }

    private func addLockedBuilding(to node: SKNode, scale: CGFloat, height: CGFloat, building: Building, conv: IsoConverter) {
        let w = scale
        let h = scale * 0.5
        let lockedHeight = max(height * 0.6, 12)

        let shape = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -w/2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h/2))
        path.addLine(to: CGPoint(x: w/2, y: 0))
        path.addLine(to: CGPoint(x: w/2, y: lockedHeight))
        path.addLine(to: CGPoint(x: 0, y: h/2 + lockedHeight))
        path.addLine(to: CGPoint(x: -w/2, y: lockedHeight))
        path.closeSubpath()
        shape.path = path
        shape.fillColor = SKColor(white: 0.5, alpha: 0.4)
        shape.strokeColor = SKColor(white: 0.4, alpha: 0.5)
        shape.lineWidth = 0.8
        node.addChild(shape)

        // Type emoji + lock
        let typeEmoji = SKLabelNode(text: building.type.emoji)
        typeEmoji.fontSize = max(scale * 0.4, 7)
        typeEmoji.verticalAlignmentMode = .center
        typeEmoji.position = CGPoint(x: 0, y: lockedHeight / 2)
        typeEmoji.zPosition = 11
        node.addChild(typeEmoji)

        let lock = SKLabelNode(text: "🔒")
        lock.fontSize = 8
        lock.position = CGPoint(x: scale * 0.3, y: lockedHeight / 2 + scale * 0.2)
        lock.verticalAlignmentMode = .center
        node.addChild(lock)

        node.alpha = 0.6
        node.zPosition = CGFloat(-node.position.y)
    }

    private func addConstructingBuilding(to node: SKNode, scale: CGFloat, height: CGFloat, building: Building) {
        let w = scale
        let h = scale * 0.5

        let shape = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -w/2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h/2))
        path.addLine(to: CGPoint(x: w/2, y: 0))
        path.addLine(to: CGPoint(x: w/2, y: height))
        path.addLine(to: CGPoint(x: 0, y: h/2 + height))
        path.addLine(to: CGPoint(x: -w/2, y: height))
        path.closeSubpath()
        shape.path = path
        shape.fillColor = SKColor(red: 1, green: 0.95, blue: 0.6, alpha: 0.9)
        shape.strokeColor = SKColor(red: 0.98, green: 0.66, blue: 0.15, alpha: 1)
        shape.lineWidth = 1.2
        node.addChild(shape)

        // Blink animation
        let fadeOut = SKAction.fadeAlpha(to: 0.4, duration: 0.5)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        shape.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))

        // Crane
        let craneV = SKShapeNode()
        let pathV = CGMutablePath()
        pathV.move(to: CGPoint(x: 0, y: height))
        pathV.addLine(to: CGPoint(x: 0, y: height + 20))
        craneV.path = pathV
        craneV.strokeColor = SKColor(red: 0.96, green: 0.49, blue: 0.09, alpha: 1)
        craneV.lineWidth = 1.5
        node.addChild(craneV)

        let craneH = SKShapeNode()
        let pathH = CGMutablePath()
        pathH.move(to: CGPoint(x: 0, y: height + 20))
        pathH.addLine(to: CGPoint(x: 14, y: height + 17))
        craneH.path = pathH
        craneH.strokeColor = SKColor(red: 0.96, green: 0.49, blue: 0.09, alpha: 1)
        craneH.lineWidth = 1.5
        node.addChild(craneH)

        // Label
        let label = SKLabelNode(text: "🏗 \(building.displayName)")
        label.fontSize = 7
        label.fontColor = SKColor(red: 0.9, green: 0.4, blue: 0, alpha: 1)
        label.fontName = "Helvetica-Bold"
        label.position = CGPoint(x: 0, y: height + 28)
        node.addChild(label)

        node.zPosition = CGFloat(-node.position.y)
    }

    // MARK: - Colors

    private func wallColorLeft(_ type: BuildingType) -> SKColor {
        switch type {
        case .residential, .apartments: return SKColor(red: 0.66, green: 0.85, blue: 0.6, alpha: 1)
        case .shop, .supermarket:       return SKColor(red: 1.0,  green: 0.84, blue: 0.31, alpha: 1)
        case .school:                   return SKColor(red: 0.56, green: 0.79, blue: 0.91, alpha: 1)
        case .hospital:                 return SKColor(red: 0.9,  green: 0.9,  blue: 0.9,  alpha: 1)
        case .office:                   return SKColor(red: 0.81, green: 0.58, blue: 0.85, alpha: 1)
        case .industrial, .powerPlant:  return SKColor(red: 1.0,  green: 0.72, blue: 0.3,  alpha: 1)
        default:                        return SKColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)
        }
    }

    private func wallColorRight(_ type: BuildingType) -> SKColor {
        wallColorLeft(type).withAlphaComponent(0.75)
    }

    private func roofColor(_ type: BuildingType) -> SKColor {
        switch type {
        case .residential:  return SKColor(red: 0.91, green: 0.72, blue: 0.49, alpha: 1)
        case .apartments:   return SKColor(red: 0.6,  green: 0.8,  blue: 1.0,  alpha: 1)
        case .shop, .supermarket: return SKColor(red: 0.95, green: 0.6, blue: 0.13, alpha: 1)
        case .school:       return SKColor(red: 0.25, green: 0.6, blue: 0.8, alpha: 1)
        case .hospital:     return SKColor(red: 0.8,  green: 0.2, blue: 0.2,  alpha: 1)
        case .office:       return SKColor(red: 0.6,  green: 0.35, blue: 0.7, alpha: 1)
        case .industrial:   return SKColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1)
        default:            return SKColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        }
    }

    // MARK: - Tap Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        // Find tapped building node
        let nodes = self.nodes(at: loc)
        for node in nodes {
            if let name = node.parent?.name ?? node.name,
               let building = buildings.first(where: { $0.id == name }) {
                onBuildingTapped?(building)
                return
            }
        }
    }

    // MARK: - Gestures

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = view else { return }
        let translation = gesture.translation(in: view)
        let scale = cameraNode.xScale

        cameraNode.position.x -= translation.x * scale
        cameraNode.position.y += translation.y * scale
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let newScale = cameraNode.xScale / gesture.scale
        cameraNode.xScale = min(max(newScale, 0.2), 10.0)
        cameraNode.yScale = cameraNode.xScale
        gesture.scale = 1.0
    }

    // MARK: - Update Building State

    func updateBuilding(_ building: Building) {
        guard let node = buildingNodes[building.id] else { return }
        node.removeFromParent()
        buildingNodes.removeValue(forKey: building.id)

        let newNode = buildingNode(for: building)
        addChild(newNode)
        buildingNodes[building.id] = newNode
    }

    // MARK: - Helpers

    private func avgLat(_ building: Building) -> Double {
        guard !building.coordinates.isEmpty else { return 0 }
        return building.coordinates.map { $0.latitude }.reduce(0, +) / Double(building.coordinates.count)
    }
}
