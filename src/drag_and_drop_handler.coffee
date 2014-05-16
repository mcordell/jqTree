class DragAndDropHandler

    constructor: (tree_widget) ->
        @tree_widget = tree_widget

        @hovered_area = null
        @$ghost = null
        @hit_areas = []
        @is_dragging = false
        @current_item = null
        @current_item_area = null;
        @debugHits = false
        @previousY = null
        @previousX = null
        @direction = null
        @horizontal_direction = null
        @horizontal_cont = 0
        @pervious_area = null

    hideMovingArea: () ->
        $('.jqtree-moving').hide()
        @refresh()

    bumpElement: (element) ->
       #console.log('Bumping element')
        $(element).addClass('bumped')

    debumpElement: () ->
        if $('.bumped')
            $('.bumped').removeClass('bumped')

    mouseCapture: (position_info) ->
        $element = $(position_info.target)

        if @tree_widget.options.onIsMoveHandle and not @tree_widget.options.onIsMoveHandle($element)
            return null

        node_element = @tree_widget._getNodeElement($element)

        if node_element and @tree_widget.options.onCanMove
            if not @tree_widget.options.onCanMove(node_element.node)
                node_element = null

        @current_item = node_element
        return (@current_item != null)

    mouseStart: (position_info) ->
        offset = $(position_info.target).offset()

        @drag_element = new DragElement(
            @current_item.node
            position_info.page_x - offset.left,
            position_info.page_y - offset.top,
            @tree_widget.element
        )

        @is_dragging = true
        @current_item.$element.addClass('jqtree-moving')

        @refresh()
        return true

    mouseDrag: (position_info) ->
        current_y = position_info.page_y
        current_x = position_info.page_x

        #set our directions
        if (@previousY == null)
            @direction = DragAndDropHandler.NEUTRAL
        else if (@previousY > current_y)
            @direction = DragAndDropHandler.UP
        else if (@previousY < current_y)
            @direction = DragAndDropHandler.DOWN
        @previousY = current_y

        if (@previousX == null)
            horizontalDirection = DragAndDropHandler.NEUTRAL
            @previousX = current_x
        else if (current_x > (@previousX + 10))
            @previousX = current_x
            horizontalDirection = DragAndDropHandler.RIGHT
        else if (current_x < (@previousX - 10))
            @previousX = current_x
            horizontalDirection = DragAndDropHandler.LEFT
        else
            horizontalDirection = DragAndDropHandler.NEUTRAL


        #move the element
        @drag_element.move(current_x, current_y)


        leaving = @leavingMovingArea(current_x, current_y)
        leavingGhost = @leavingGhostArea(current_x, current_y)

        if leaving
            @hovered_area = @findAreaWhenLeaving(leaving, current_x, current_y)
            @hideMovingArea()
            @updateDropHint()
            @refresh()
           #console.log('leave move done')
        else if (leavingGhost)
           #console.log('Leaving Ghost' + leavingGhost + "Direction " + @direction)
            if (leavingGhost == @direction)
                @hovered_area = @findAreaWhenLeaving(leavingGhost, current_x, current_y, true)
                if (@hovered_area != @previous_area)
                    @previous_area = @hovered_area
                    @updateDropHint()
                    @refresh()
                    @previousX = current_x
                   #console.log('Ghost move done')
        else if horizontalDirection == DragAndDropHandler.RIGHT
            #@printCursorAndAround()
            el = if $('.jqtree-moving').is(':visible') then $('.jqtree-moving') else $('.jqtree-ghost')
            area = @findAreaRightToggle(current_x, current_y)

            if (area.position == Position.INSIDE && area.node.hasChildren() && !area.node.isOpen())
                @tree_widget._openNode(
                    area.node,
                    @tree_widget.options.slide,
                    =>
                        @refresh()
                )
                @previousX = current_x
                @hovered_area = area
                @updateDropHint();
            else if @canBump(el, area)
                @bumpElement(el)
                @hovered_area = area
        else if horizontalDirection == DragAndDropHandler.LEFT
            @printCursorAndAround()
            console.log('LEFT')
            el = if $('.jqtree-moving').is(':visible') then $('.jqtree-moving') else $('.jqtree-ghost')
            leftBump = @tryLeftBump(el)
            if leftBump
                console.log('leftBumping')
                @hovered_area = leftBump
                @pervious_x = current_x
                if $('.jqtree-moving').is(':visible')
                    el.addClass('leftBumped')
                else
                    @updateDropHint();
        return true

    printCursorAndAround: () ->
        el = if $('.jqtree-moving').is(':visible') then $('.jqtree-moving') else $('.jqtree-ghost')
        [cursorPosition,index] = @findAreaForPlaceholder(el)
        next = @hit_areas[index+1]
        previous = @hit_areas[index-1]
        if cursorPosition
            console.log("Cursor:", cursorPosition)
        if next
            console.log("Next:", next)
        if previous
            console.log("previous", previous)

    tryLeftBump: (el) ->
        [cursorPosition,index] = @findAreaForPlaceholder(el)
        next = @hit_areas[index+1]
        if next && next.level == cursorPosition.level - 1 && next.position == Position.AFTER
            return next
        return false

    canBump: (el, area) ->
        [cursorPosition,index] = @findAreaForPlaceholder(el)
        previous = @hit_areas[index-1]

        valueToReturn = false
        if (cursorPosition.position == Position.NONE)
            valueToReturn = if (previous && previous.position == Position.AFTER) then true else false
        if (cursorPosition.position == Position.AFTER && previous && previous.position == Position.INSIDE && previous.level == cursorPosition.level)
            valueToReturn = true

        return valueToReturn

    canMoveToArea: (area) ->
        if not area
            return false
        else if @tree_widget.options.onCanMoveTo
            position_name = Position.getName(area.position)

            return @tree_widget.options.onCanMoveTo(@current_item.node, area.node, position_name)
        else
            return true

    findAreaForPlaceholder: (el) ->
        [area,index] = @findHoveredAreaWithIndex(el.offset().left, el.offset().top)
       #console.log(area.node.name, area.position, index )

    inMovingArea: (x,y) ->
        moving_area_top = $('.jqtree-moving').offset().top
        moving_area_bottom = $('.jqtree-moving').height() + moving_area_top
        if not $('.jqtree-moving').is(':visible')
            return false
        if ( y > moving_area_top && y < moving_area_bottom)
            return true
        else
            return false

    leavingGhostArea: (x,y) ->
        return false  unless $(".jqtree-ghost").is(":visible")
        ghost_top = $(".jqtree-ghost").offset().top
        ghost_bottom = $(".jqtree-ghost").height() + ghost_top
        return false  if y > ghost_top and y < ghost_bottom
        return DragAndDropHandler.DOWN  if y > ghost_bottom
        return DragAndDropHandler.UP  if y < ghost_top
        return false

    leavingMovingArea: (x,y) ->
        return false  unless $(".jqtree-moving").is(":visible")
        moving_area_top = $(".jqtree-moving").offset().top
        moving_area_bottom = $(".jqtree-moving").height() + moving_area_top
        return -1  if y > moving_area_bottom
        return 1  if y < moving_area_top
        return false

    mouseStop: (position_info) ->
        @moveItem(position_info)
        @clear()
        @removeHover()
        @removeDropHint()
        @removeHitAreas()
        @previousX = null
        @previousY = null

        if @current_item
            @current_item.$element.show()
            @current_item.$element.removeClass('jqtree-moving')
            @current_item = null

        @is_dragging = false
        return false

    refresh: ->
        @removeHitAreas()
        @generateHitAreas()

        if @current_item
            @current_item = @tree_widget._getNodeElementForNode(@current_item.node)

            if @is_dragging
                @current_item.$element.addClass('jqtree-moving')


    removeHitAreas: ->
        @hit_areas = []

    clear: ->
        @drag_element.remove()
        @drag_element = null

    removeDropHint: ->
        if @previous_ghost
            @previous_ghost.remove()

    removeHover: ->
        @hovered_area = null

    generateHitAreas: ->
        hit_areas_generator = new HitAreasGenerator(
            @tree_widget.tree,
            @current_item.node,
            @getTreeDimensions().bottom
        )
        @hit_areas = hit_areas_generator.generate()

        if (@debugHits)
            for area in @hit_areas
                switch (area.position)
                    when 2 then position = 'After'
                    when 3 then position = 'Inside'
                    when 1 then position = 'Before'
                    when 4 then position = 'None'

               #console.log(area.top, area.bottom, area.node.name, position)

    findAreaWhenLeaving: (leaving, x, y, ghost) ->
        dimensions = @getTreeDimensions()

        if (
            x < dimensions.left or
            y < dimensions.top or
            x > dimensions.right or
            y > dimensions.bottom
        )
            return null

        low = 0
        high = @hit_areas.length
        while (low < high)
            mid = (low + high) >> 1
            area = @hit_areas[mid]

            if y < area.top
                high = mid
            else if y > area.bottom
                low = mid + 1
            else
                areaId = mid
                if (ghost && leaving == 1 && area.position != Position.AFTER)
                    areaBefore = @hit_areas[areaId-1]
                    if (areaBefore && areaBefore.position != Position.AFTER)
                       #console.log('Special Return up' + area.position + " " + area.top)
                        return areaBefore
                if (ghost && leaving == -1 && area.position != Position.AFTER)
                    areaAfter = @hit_areas[areaId+1]
                    if (areaAfter.position != Position.AFTER)
                        if ghost
                           #console.log('GHOST Special Return down: ' + area.position + " " + area.top)
                            return area
                        else
                            return areaAfter
                while (leaving == 1 && areaId > 0 && area.position != Position.AFTER)
                   #console.log('Position = ' + area.position + ' subtracting')
                    areaId--
                    area = @hit_areas[areaId]
                while (leaving == -1 && areaId < @hit_areas.length && area.position != Position.AFTER)
                   #console.log('Position = ' + area.position + ' adding')
                    areaId++
                    area = @hit_areas[areaId]
               #console.log('Returning '+ area.position + " " + area.top)
                return area
        return null

    findAreaRightToggle: (x, y) ->
        dimensions = @getTreeDimensions()

        if (
            x < dimensions.left or
            y < dimensions.top or
            x > dimensions.right or
            y > dimensions.bottom
        )
            return null

        low = 0
        high = @hit_areas.length
        while (low < high)
            mid = (low + high) >> 1
            area = @hit_areas[mid]

            if y < area.top
                high = mid
            else if y > area.bottom
                low = mid + 1
            else
                areaId = mid
                #console.log(area.node.name, area.position)
                while (areaId > 0 && area.position != Position.INSIDE)

                    areaId--
                    area = @hit_areas[areaId]
                return area
        return null

    findHoveredAreaWithIndex: (x,y) ->
        dimensions = @getTreeDimensions()

        if (
            x < dimensions.left or
            y < dimensions.top or
            x > dimensions.right or
            y > dimensions.bottom
        )
            return [null,null]

        low = 0
        high = @hit_areas.length
        while (low < high)
            mid = (low + high) >> 1
            area = @hit_areas[mid]

            if y < area.top
                high = mid
            else if y > area.bottom
                low = mid + 1
            else
                return [area, mid]

        return [null,null]

    findHoveredArea: (x, y) ->
        dimensions = @getTreeDimensions()

        if (
            x < dimensions.left or
            y < dimensions.top or
            x > dimensions.right or
            y > dimensions.bottom
        )
            return null

        low = 0
        high = @hit_areas.length
        while (low < high)
            mid = (low + high) >> 1
            area = @hit_areas[mid]

            if y < area.top
                high = mid
            else if y > area.bottom
                low = mid + 1
            else
                return area

        return null

    mustOpenFolderTimer: (area) ->
        node = area.node

        return (
            node.isFolder() and
            not node.is_open and
            area.position == Position.INSIDE
        )

    updateDropHint: ->
        if not @hovered_area
            return

        # remove previous drop hint
        @removeDropHint()

        # add new drop hint
        node_element = @tree_widget._getNodeElementForNode(@hovered_area.node)
        @previous_ghost = node_element.addDropHint(@hovered_area.position)

    startOpenFolderTimer: (folder) ->
        openFolder = =>
            @tree_widget._openNode(
                folder,
                @tree_widget.options.slide,
                =>
                    @refresh()
                    @updateDropHint()
            )

        @stopOpenFolderTimer()

        @open_folder_timer = setTimeout(openFolder, @tree_widget.options.openFolderDelay)

    stopOpenFolderTimer: ->
        if @open_folder_timer
            clearTimeout(@open_folder_timer)
            @open_folder_timer = null

    moveItem: (position_info) ->
        if (
            @hovered_area and
            @hovered_area.position != Position.NONE and
            @canMoveToArea(@hovered_area)
        )
            moved_node = @current_item.node
            target_node = @hovered_area.node
            position = @hovered_area.position
            previous_parent = moved_node.parent

            if position == Position.INSIDE
                @hovered_area.node.is_open = true

            doMove = =>
                @tree_widget.tree.moveNode(moved_node, target_node, position)
                @tree_widget.element.empty()
                @tree_widget._refreshElements()

            event = @tree_widget._triggerEvent(
                'tree.move',
                move_info:
                    moved_node: moved_node
                    target_node: target_node
                    position: Position.getName(position)
                    previous_parent: previous_parent
                    do_move: doMove
                    original_event: position_info.original_event
            )

            doMove() unless event.isDefaultPrevented()

    getTreeDimensions: ->
        # Return the dimensions of the tree. Add a margin to the bottom to allow
        # for some to drag-and-drop the last element.
        offset = @tree_widget.element.offset()

        return {
            left: offset.left,
            top: offset.top,
            right: offset.left + @tree_widget.element.width(),
            bottom: offset.top + @tree_widget.element.height() + 80
        }

DragAndDropHandler.UP = 1
DragAndDropHandler.DOWN = -1
DragAndDropHandler.RIGHT = 1
DragAndDropHandler.LEFT = -1
DragAndDropHandler.NEUTRAL = 0

class VisibleNodeIterator
    constructor: (tree) ->
        @tree = tree

    iterate: ->
        is_first_node = true

        _iterateNode = (node, next_node, depth) =>

            must_iterate_inside = (
                (node.is_open or not node.element) and node.hasChildren()
            )

            if node.element
                $element = $(node.element)

                if not $element.is(':visible')
                    return

                if is_first_node
                    @handleFirstNode(node, $element, depth)
                    is_first_node = false

                if not node.hasChildren()
                    @handleNode(node, next_node, $element, depth)
                else if node.is_open
                    if not @handleOpenFolder(node, $element, depth)
                        must_iterate_inside = false
                else
                    @handleClosedFolder(node, next_node, $element, depth)

            if must_iterate_inside
                children_length = node.children.length
                for child, i in node.children
                    if i == (children_length - 1)
                        _iterateNode(node.children[i], null, depth + 1)
                    else
                        _iterateNode(node.children[i], node.children[i+1], depth + 1)

                if node.is_open
                    @handleAfterOpenFolder(node, next_node, $element, depth)

        _iterateNode(@tree, null, 0)

    handleNode: (node, next_node, $element, depth) ->
        # override

    handleOpenFolder: (node, $element, depth) ->
        # override
        # return
        #   - true: continue iterating
        #   - false: stop iterating

    handleClosedFolder: (node, next_node, $element, depth) ->
        # override

    handleAfterOpenFolder: (node, next_node, $element, depth) ->
        # override

    handleFirstNode: (node, $element, depth) ->
        # override

class HitAreasGenerator extends VisibleNodeIterator
    constructor: (tree, current_node, tree_bottom) ->
        super(tree)

        @current_node = current_node
        @tree_bottom = tree_bottom

    generate: ->
        @positions = []
        @last_top = 0

        @iterate()

        return @generateHitAreas(@positions)

    getTop: ($element) ->
        return $element.offset().top

    addPosition: (node, position, top, depth) ->
        area = {
            top: top
            node: node
            position: position
            level: depth
        }

        @positions.push(area)
        @last_top = top

    handleNode: (node, next_node, $element, depth) ->
        top = @getTop($element)

        if node == @current_node
            # Cannot move inside current item
            @addPosition(node, Position.NONE, top, depth)
        else
            @addPosition(node, Position.INSIDE, top, depth)
            @addPosition(node, Position.AFTER, top, depth)

    handleOpenFolder: (node, $element, depth) ->
        # Cannot move inside current item
        # Stop iterating
        return false if node == @current_node
        @addPosition(node, Position.INSIDE, @getTop($element), depth)

        # Continue iterating
        return true

    handleClosedFolder: (node, next_node, $element, depth) ->
        top = @getTop($element)
        @addPosition node, Position.INSIDE, top, depth
        @addPosition node, Position.AFTER, top, depth

    handleFirstNode: (node, $element, depth) ->
        if node != @current_node
            @addPosition(node, Position.BEFORE, @getTop($(node.element)), depth)

    handleAfterOpenFolder: (node, next_node, $element, depth) ->
        if (
            node == @current_node.node or
            next_node == @current_node.node
        )
            # Cannot move before or after current item
            @addPosition(node, Position.NONE, @last_top, depth)
        else
            @addPosition(node, Position.AFTER, @last_top, depth)

    generateHitAreas: (positions) ->
        previous_top = -1
        group = []
        hit_areas = []

        for position in positions
            if position.top != previous_top and group.length
                if group.length
                    @generateHitAreasForGroup(
                        hit_areas,
                        group,
                        previous_top,
                        position.top
                    )

                previous_top = position.top
                group = []

            group.push(position)

        @generateHitAreasForGroup(
            hit_areas,
            group,
            previous_top,
            @tree_bottom
        )

        return hit_areas

    generateHitAreasForGroup: (hit_areas, positions_in_group, top, bottom) ->
        # limit positions in group

        position_count = Math.min(positions_in_group.length, 4)
        area_height = Math.round((bottom - top) / position_count)
        area_top = top

        i = 0
        while (i < position_count)
            position = positions_in_group[i]

            hit_areas.push(
                top: area_top,
                bottom: area_top + area_height,
                node: position.node,
                position: position.position
                level: position.level
            )

            area_top += area_height
            i += 1

        return null

class DragElement
    constructor: (node, offset_x, offset_y, $tree) ->
        @offset_x = offset_x
        @offset_y = offset_y

        @$element = $("<div class=\"jqtree-title jqtree-dragging\"></div>")
        @$element.append($(node.element).clone())
        #@$element = $("<span class=\"jqtree-title jqtree-dragging\">#{ node.name }</span>")
        @$element.css("position", "absolute")
        $tree.append(@$element)

    move: (page_x, page_y) ->
        @$element.offset(
            left: page_x - @offset_x,
            top: page_y - @offset_y
        )

    remove: ->
        @$element.remove()


class GhostDropHint
    constructor: (node, $element, position) ->
        @$element = $element

        @node = node
        height =  $('.jqtree-moving').height()
        @$ghost = $('<li style = "height:'+height+'px;" class="jqtree_common jqtree-ghost"><span class="jqtree_common jqtree-circle"></span><span class="jqtree_common jqtree-line"></span></li>')

        if position == Position.AFTER
            @moveAfter()
        else if position == Position.BEFORE
            @moveBefore()
        else if position == Position.INSIDE
            if node.isFolder() and node.is_open
                @moveInsideOpenFolder()
            else
                @moveInside()

    remove: ->
        @$ghost.remove()

    moveAfter: ->
        @$element.after(@$ghost)

    moveBefore: ->
        @$element.before(@$ghost)

    moveInsideOpenFolder: ->
        $(@node.children[0].element).before(@$ghost)

    moveInside: ->
        @$element.after(@$ghost)
        @$ghost.addClass('jqtree-inside')


class BorderDropHint
    constructor: ($element) ->
        $div = $element.children('.jqtree-element')
        width = $element.width() - 4

        @$hint = $('<span class="jqtree-border"></span>')
        $div.append(@$hint)

        @$hint.css(
            width: width
            height: $div.height() - 4
        )

    remove: ->
        @$hint.remove()
