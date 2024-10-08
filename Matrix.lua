Element = {}
Element.__index = Element

function Element:new(element_id)
    local obj = {
        id = element_id,
        connections = {}
    }
    setmetatable(obj, self)
    return obj
end

function Element:add_connection(element)
    table.insert(self.connections, element)
end

function Element:get_connections()
    return self.connections
end

function Element:__tostring()
    local conn_ids = {}
    for _, el in ipairs(self.connections) do
        table.insert(conn_ids, el.id)
    end
    return string.format("Element(id=%d, connections={%s})", self.id, table.concat(conn_ids, ", "))
end

Network = {}
Network.__index = Network

function Network:new()
    local obj = {
        elements = {}
    }
    setmetatable(obj, self)
    return obj
end

function Network:add_element(element_id)
    if not self.elements[element_id] then
        self.elements[element_id] = Element:new(element_id)
    end
end

function Network:connect_elements(from_id, to_id)
    local from_element = self.elements[from_id]
    local to_element = self.elements[to_id]
    if from_element and to_element then
        from_element:add_connection(to_element)
    end
end

function Network:generate_connection_matrix()
    local n = #self.elements
    local connection_matrix = {}

    for i = 1, n do
        connection_matrix[i] = {}
        for j = 1, n do
            connection_matrix[i][j] = 0
        end
    end

    for _, element in pairs(self.elements) do
        local element_index = element.id
        for _, connected_element in ipairs(element:get_connections()) do
            local connected_index = connected_element.id
            connection_matrix[element_index][connected_index] = connection_matrix[element_index][connected_index] + 1
        end
    end

    return self:concat_matrix(connection_matrix, self:transpose_matrix(connection_matrix))
end

function Network:transpose_matrix(matrix)
    local transposed = {}
    for i = 1, #matrix do
        transposed[i] = {}
        for j = 1, #matrix[i] do
            transposed[i][j] = matrix[j][i]
        end
    end
    return transposed
end

function Network:concat_matrix(matrix, transposed_matrix)
    for i = 1, #matrix do
        for j = 1, #matrix[i] do
            matrix[i][j] = math.max(transposed_matrix[i][j], matrix[i][j])
        end
    end
    return matrix
end

LocationScheme = {}
LocationScheme.__index = LocationScheme

function LocationScheme:new(weights, locations)
    local obj = {
        weights = {table.unpack(weights)},
        locations = {table.unpack(locations)}
    }
    setmetatable(obj, self)
    return obj
end

function LocationScheme:generate_locations_matrix()
    local n = #self.locations
    local distance_matrix = {}

    for i = 1, n do
        distance_matrix[i] = {}
        for j = 1, n do
            if i == j then
                distance_matrix[i][j] = 0
            else
                distance_matrix[i][j] = self:calculate_distance(i, j)
            end
        end
    end

    return distance_matrix
end

function LocationScheme:calculate_distance(i, j)
    local distance = 0
    local index1 = math.min(table.index_of(self.locations, i), table.index_of(self.locations, j))
    local index2 = math.max(table.index_of(self.locations, i), table.index_of(self.locations, j))

    for k = index1, index2 - 1 do
        distance = distance + self.weights[k]
    end

    return distance
end

function LocationScheme:get_locations()
    return self.locations
end

function LocationScheme:__tostring()
    return string.format("LocationScheme(weights={%s}, locations={%s})", table.concat(self.weights, ", "), table.concat(self.locations, ", "))
end

Arrangement = {}
Arrangement.__index = Arrangement

function Arrangement:new(network, location_scheme)
    local obj = {
        network = network,
        location_scheme = location_scheme
    }
    setmetatable(obj, self)
    return obj
end

function Arrangement:count_k()
    local count = 0
    local connection_matrix = self.network:generate_connection_matrix()
    local locations_matrix = self.location_scheme:generate_locations_matrix()

    for i = 1, #connection_matrix do
        for j = 1, #connection_matrix[i] do
            count = count + connection_matrix[i][j] * locations_matrix[i][j]
        end
    end
    return math.floor(count / 2)
end

function Arrangement:count_rows(matrix)
    local row_sums = {}
    for i = 1, #matrix do
        local row_sum = 0
        for j = 1, #matrix[i] do
            row_sum = row_sum + matrix[i][j]
        end
        row_sums[i] = row_sum
    end
    return row_sums
end

function Arrangement:reshuffle()
    local star_d = self:count_rows(self.location_scheme:generate_locations_matrix())
    local star_c = self:count_rows(self.network:generate_connection_matrix())

    print("C*: ")
    for _, value in ipairs(star_c) do
        print(value)
    end

    print("D*: ")
    for _, value in ipairs(star_d) do
        print(value)
    end

    local new_order = {}
    local normal = self.location_scheme:get_locations()

    for _ = 1, #normal do
        local max_index = table.max_index(star_c)
        local min_index = table.min_index(star_d)

        local normal_max_index = table.index_of(normal, max_index)
        local normal_min_index = table.index_of(normal, min_index)

        new_order[normal_min_index] = normal[normal_max_index]

        star_c[max_index] = 0
        star_d[min_index] = math.huge
    end

    self.location_scheme.locations = new_order
    return new_order
end

function Arrangement:calculate_final_k()
    return self:count_k()
end

table.index_of = function(t, value)
    for i, v in ipairs(t) do
        if v == value then return i end
    end
    return nil
end

table.max_index = function(t)
    local max_val = -math.huge
    local max_index = 1
    for i, v in ipairs(t) do
        if v > max_val then
            max_val = v
            max_index = i
        end
    end
    return max_index
end

table.min_index = function(t)
    local min_val = math.huge
    local min_index = 1
    for i, v in ipairs(t) do
        if v < min_val then
            min_val = v
            min_index = i
        end
    end
    return min_index
end

-- Main execution
function main()
    local network = Network:new()

    io.write("Connections: ")
    local num_elements = tonumber(io.read())

    for i = 1, num_elements do
        network:add_element(i)
    end

    print("Enter the relations of the matrix:")
    while true do
        local connection = io.read()
        if connection:lower() == "all" then
            break
        end
        local from_id, to_id = connection:match("(%d+)%s+(%d+)")
        network:connect_elements(tonumber(from_id), tonumber(to_id))
    end

    io.write("Enter weights: ")
    local weights = {}
    for w in io.read():gmatch("%d+") do
        table.insert(weights, tonumber(w))
    end

    io.write("Enter positions: ")
    local locations = {}
    for l in io.read():gmatch("%d+") do
        table.insert(locations, tonumber(l))
    end

    local location_scheme = LocationScheme:new(weights, locations)

    print("\nInitial scheme:")
    print(location_scheme)

    print("\nMatrix D:")
    local d_matrix = location_scheme:generate_locations_matrix()
    for _, row in ipairs(d_matrix) do
        print(table.concat(row, " "))
    end

    print("\nMatrix C:")
    local arrangement_solution = Arrangement:new(network, location_scheme)
    local c_matrix = arrangement_solution.network:generate_connection_matrix()
    for _, row in ipairs(c_matrix) do
        print(table.concat(row, " "))
    end

    local initial_k_value = arrangement_solution:count_k()
    print("K (initial) = " .. initial_k_value)

    local result_order = arrangement_solution:reshuffle()

    print("\nAfter Moving.")
    print("\nFinal scheme:")
    print(location_scheme)

    local final_k_value = arrangement_solution:calculate_final_k()
    print("K (final) = " .. final_k_value)

    local initial_cost = initial_k_value
    local final_cost = final_k_value
    local efficiency = ((initial_cost - final_cost) / initial_cost) * 100

    print(string.format("Efficiency E = %.2f%%", efficiency))
end

main()