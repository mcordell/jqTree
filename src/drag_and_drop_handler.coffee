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
        console.log('Bumping element')
        $(element).addClass('bumped')

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
        rightmove = false
        if (@previousY == null)
            @direction = null
        else if (@previousY > position_info.page_y)
            @direction = DragAndDropHandler.UP
        else if (@previousY < position_info.page_y)
            @direction = DragAndDropHandler.DOWN

        if (@previousX == null)
            area = @previousX = position_info.page_x
        else if (@previousX+10 < position_info.page_x)
            rightmove = true
            console.log('Triggered')
        else
            console.log(@previousX, position_info.page_x)

        #@triggeringRightMove(position_info.page_x, position_info.page_y)

       # @previousX = position_info.page_x
        @previousY = position_info.page_y
        @drag_element.move(position_info.page_x, position_info.page_y)


        if rightmove
            area = @findAreaRightToggle(position_info.page_x, position_info.page_y)
            if (area.position == Position.INSIDE && area.node.hasChildren() && !area.node.isOpen())
                @tree_widget._openNode(
                    area.node,
                    @tree_widget.options.slide,
                    =>
                        @refresh()
                )
                @previousX = position_info.page_x
            else
                el = $('.jqtree-ghost')
                if (el.is(':visible'))
                    @bumpElement(el)
                    @hovered_area = area
                el = $('.jqtree-moving')
                if (el.is(':visible'))
                    @bumpElement(el)
                    @hovered_area = area
        else
            #console.log("X: "+position_info.page_x+" Y: "+position_info.page_y)
            area = @findHoveredArea(position_info.page_x, position_info.page_y)
            leaving = @leavingMovingArea(position_info.page_x, position_info.page_y)
            leavingGhost = @leavingGhostArea(position_info.page_x, position_info.page_y)
            #if @inMovingArea(position_info.page_x, position_info.page_y)
            #    console.log("I can't let you do that dave.");
            #    can_move_to = false
            #else
            #    can_move_to = @canMoveToArea(area)


            if leaving
                @hovered_area = @findAreaWhenLeaving(leaving, position_info.page_x, position_info.page_y)
                @hideMovingArea()
                @updateDropHint()
                @refresh()
                @horizontal_cont = 0
                console.log('leave move done')
            else if (leavingGhost)
                #console.log('Leaving Ghost' + leavingGhost + "Direction " + @direction)
                if (leavingGhost == @direction)
                    @hovered_area = @findAreaWhenLeaving(leavingGhost, position_info.page_x, position_info.page_y, true)
                    if (@hovered_area != @previous_area)
                        @previous_area = @hovered_area
                        @updateDropHint()
                        @refresh()
                        @previousX = position_info.page_x
                        console.log('Ghost move done')


        return true

    canMoveToArea: (area) ->
        if not area
            return false
        else if @tree_widget.options.onCanMoveTo
            position_name = Position.getName(area.position)

            return @tree_widget.options.onCanMoveTo(@current_item.node, area.node, position_name)
        else
            return true

    inMovingArea: (x,y) ->
        moving_area_top = $('.jqtree-moving').offset().top
        moving_area_bottom = $('.jqtree-moving').height() + moving_area_top
        if not $('.jqtree-moving').is(':visible')
            return false
        if ( y > moving_area_top && y < moving_area_bottom)
            return true
        else
            return false

    triggeringRightMove: (x,y) ->
        if not $('.jqtree-ghost').is(':visible')
            return false
        ghost_left = $('.jqtree-ghost').offset().left
        console.log('Ghost_left'+ghost_left + " X:" + x)
        if (x > ghost_left + 20)
            console.log('Triggered!!')
        return false

    leavingGhostArea: (x,y) ->
        return false  unless $(".jqtree-ghost").is(":visible")
        ghost_top = $(".jqtree-ghost").offset().top
        ghost_bottom = $(".jqtree-ghost").height() + ghost_top
        return false  if y > ghost_top and y < ghost_bottom
        return -1  if y > ghost_bottom
        return 1  if y < ghost_top
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

                console.log(area.top, area.bottom, area.node.name, position)

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
                    if (areaBefore.position != Position.AFTER)
                        console.log('Special Return up' + area.position + " " + area.top)
                        return areaBefore
                if (leaving == -1 && area.position != Position.AFTER)
                    areaAfter = @hit_areas[areaId+1]
                    if (areaAfter.position != Position.AFTER)
                        if ghost
                            console.log('GHOST Special Return down: ' + area.position + " " + area.top)
                            return area
                        else
                            return areaAfter
                while (leaving == 1 && areaId > 0 && area.position != Position.AFTER)
                    console.log('Position = ' + area.position + ' subtracting')
                    areaId--
                    area = @hit_areas[areaId]
                while (leaving == -1 && areaId < @hit_areas.length && area.position != Position.AFTER)
                    console.log('Position = ' + area.position + ' adding')
                    areaId++
                    area = @hit_areas[areaId]
                console.log('Returning '+ area.position + " " + area.top)
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
                while (areaId > 0 && area.position != Position.INSIDE)
                    #console.log('Position = ' + area.position + ' subtracting')
                    areaId--
                    area = @hit_areas[areaId]
                return area
        return null

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
class VisibleNodeIterator
    constructor: (tree) ->
        @tree = tree

    iterate: ->
        is_first_node = true

        _iterateNode = (node, next_node) =>
            must_iterate_inside = (
                (node.is_open or not node.element) and node.hasChildren()
            )

            if node.element
                $element = $(node.element)

                if not $element.is(':visible')
                    return

                if is_first_node
                    @handleFirstNode(node, $element)
                    is_first_node = false

                if not node.hasChildren()
                    @handleNode(node, next_node, $element)
                else if node.is_open
                    if not @handleOpenFolder(node, $element)
                        must_iterate_inside = false
                else
                    @handleClosedFolder(node, next_node, $element)

            if must_iterate_inside
                children_length = node.children.length
                for child, i in node.children
                    if i == (children_length - 1)
                        _iterateNode(node.children[i], null)
                    else
                        _iterateNode(node.children[i], node.children[i+1])

                if node.is_open
                    @handleAfterOpenFolder(node, next_node, $element)

        _iterateNode(@tree, null)

    handleNode: (node, next_node, $element) ->
        # override

    handleOpenFolder: (node, $element) ->
        # override
        # return
        #   - true: continue iterating
        #   - false: stop iterating

    handleClosedFolder: (node, next_node, $element) ->
        # override

    handleAfterOpenFolder: (node, next_node, $element) ->
        # override

    handleFirstNode: (node, $element) ->
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

    addPosition: (node, position, top) ->
        area = {
            top: top
            node: node
            position: position
        }

        @positions.push(area)
        @last_top = top

    handleNode: (node, next_node, $element) ->
        top = @getTop($element)

        if node == @current_node
            # Cannot move inside current item
            @addPosition(node, Position.NONE, top)
        else
            @addPosition(node, Position.INSIDE, top)
            @addPosition(node, Position.AFTER, top)

    handleOpenFolder: (node, $element) ->
        # Cannot move inside current item
        # Stop iterating
        return false if node == @current_node
        @addPosition(node, Position.INSIDE, @getTop($element))

        # Continue iterating
        return true

    handleClosedFolder: (node, next_node, $element) ->
        top = @getTop($element)
        @addPosition node, Position.INSIDE, top
        @addPosition node, Position.AFTER, top

    handleFirstNode: (node, $element) ->
        if node != @current_node
            @addPosition(node, Position.BEFORE, @getTop($(node.element)))

    handleAfterOpenFolder: (node, next_node, $element) ->
        if (
            node == @current_node.node or
            next_node == @current_node.node
        )
            # Cannot move before or after current item
            @addPosition(node, Position.NONE, @last_top)
        else
            @addPosition(node, Position.AFTER, @last_top)

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
