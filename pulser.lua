
-- deterministic "time.clock", for testing
function fake_time()
	local timereal = require"time"
	local t = 0
	return function()
		t = t + 1e-5 -- increment by 1 nanosecond
		return t
	end
end

function clockmaker()
	local tc = require"time"
	local t0 = tc.clock()
	return function ()
		return tc.clock()-t0
	end
end
--local time = {}
--time.clock = clockmaker()
local time = {}
time.clock = fake_time()

math.randomseed( os.time() )

function table.permute(t) -- permute a table
	n = #t
	for i=1, n do
		local j = math.random(i, n)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

function table.merge(t1, t2)
	for k,v in ipairs(t2) do
		table.insert(t1, v)
	end
	return t1
end

function make_pulsers(_n, _initial_f, _dPulseT, _numSimultaneous)
	local n = _n
	local dPulseT = _dPulseT -- seconds
	local numSimultaneous = _numSimultaneous
	local t0 = time.clock()
	local tLast = -math.huge -- ie -Inf
	local pulseQ = {} -- for storing pulses until they can be sent
	local o = {}
	for i=1, n do
		local data = {}
		data.id = i
		data.qLast = math.random() * 2*math.pi
		data.f  = _initial_f[i]
		o[i] = data
	end
	table.sort(o, function(a,b) return a.f>b.f end) -- sort by freq, descending

	-- create another version of f that does not care about dead time
	-- and return that version when dead time is zero
	-- this saves having to use an if statement

	local priority_pulser = function(f)

		if f then
			if #f ~= n then
				error("length of f is wrong")
			end
			for i=1,n do
				o[i].f = f[i]
			end
		end

		o = permute(o)

		local t = time.clock()
		for i=1,n do
			if (t-o[i].t0)*o[i].f > 1 then
				local do_pulse = true
				for j=1,i-1 do
					if (t-o[j].t0) < dead_time then
						o[i].t0 = o[i].t0 + dead_time
						do_pulse = false
						break
					end
				end
				if do_pulse then
					o[i].t0 = t
					io.write(o[i].id, "\t", t, "\n") -- faster than print
				end
			end
		end
	end

	local prioritize_hf_pulser = function (f)

		-- assume if we dont provide f, that o.f is already sorted
		if f then
			if #f ~= n then
				error("length of f is wrong")
			end
			-- actually the below lines arent quite right
			table.sort(f, function(a,b) return a>b end)
			for i=1,n do
				o[i].f = f[i]
			end
		end

		local t = time.clock()
		for i=1,n do
			if (t-o[i].t0) >= 1/o[i].f then
				local do_pulse = true
				for j=1,i-1 do
					if (t-o[j].t0) < dead_time then
						o[i].t0 = o[i].t0 + dead_time
						do_pulse = false
						break
					end
				end
				if do_pulse then
					o[i].t0 = t
					io.write(o[i].id, "\t", t, "\n") -- faster than print
				end
			end
		end
	end

	-- this pulser either delays OR brings pulses earlier
	-- "Bring pulses forward if you can; delay if you must"
	local pulser_v3 = function(f)

		if f then
			if #f ~= n then
				error("length of f is wrong")
			end
			for i=1,n do
				o[i].f = f[i]
			end
		end

		-- maybe better to make this permute a sort? XXX
		--o = permute(o)

		local t = time.clock()

		-- do we expect any pulses in this interval?
		local pulse_now = {}
		local pulse_next = {}
		local tlast = -math.huge
		for i=1,n do
			if (t-o[i].t0) > 1/o[i].f then
				table.insert(pulse_now, i)
			elseif (t-o[i].t0+dead_time) > 1/o[i].f then
				table.insert(pulse_next, i)
			end
			if o[i].t0 > tlast then
				tlast = o[i].t0
			end
		end

		-- there are zero pulses scheduled now
		if #pulse_now == 0 then
			if (t-tlast) > dead_time then
				if math.random() > 0.5 then
					if #pulse_next >= 2 then -- at least two next; bring first forward
						o[pulse_next[1]].t0 = t
						io.write(o[pulse_next[1]].id, "\t", t, "\n")
					end
					if #pulse_next >= 3 then -- at least three next; send second back
						o[pulse_next[2]].t0 = o[pulse_next[2]].t0 + dead_time
					end
				else
					if #pulse_next >= 2 then -- at least two next; send first back
						o[pulse_next[1]].t0 = o[pulse_next[1]].t0 + dead_time
					end
					if #pulse_next >= 3 then -- at least three next; bring second forward
						o[pulse_next[2]].t0 = t
						io.write(o[pulse_next[2]].id, "\t", t, "\n")
					end
				end
			end
		else -- one or more pulses now
			if (t-tlast) > dead_time then
				o[pulse_now[#pulse_now]].t0 = t -- highest freq gets priority
				io.write(o[pulse_now[#pulse_now]].id, "\t", t, "\n")
				for j=1,#pulse_now-1 do
					o[pulse_now[j]].t0 = o[pulse_now[j]].t0 + dead_time
				end
			else
				for j=1,#pulse_now do
					o[pulse_now[j]].t0 = o[pulse_now[j]].t0 + dead_time
				end
			end
		end

		return t
	end

	-- this one follows flip's idea
	local pulser_v4a = function(f)

		if f then
			if #f ~= n then
				error("length of f is wrong")
			end
			for i=1,n do
				o[i].f = f[i]
			end
			table.sort(o, function(a,b) return a.f>b.f end) -- sort by freq, descending
		end

		local t = time.clock() -- advance clock

		local dt = t - t0;

		-- what pulses are happening in this interval
		local qtmp = {}
		for i=1,n do
			local qnew = (o[i].qLast + dt*o[i].f*2*math.pi) % (2*math.pi) -- advance phase
			if qnew < o[i].qLast then -- gone over 2 pi boundary
				table.insert(qtmp, {f=o[i].f, id=o[i].id})
			end
			o[i].qLast = qnew -- update last phase
		end

		--table.sort(qtmp, function(a,b) return a.f>b.f end) -- highest freq goes first
		qtmp = table.permute(qtmp)

		pulseQ = table.merge(pulseQ, qtmp)

		-- so right now this queue is only emptied out on the edges. is that best?

		-- Do I need to pulse and can I?
		if #pulseQ > 0 and (t-tLast) > dPulseT then
			for i=1,math.min(#pulseQ,numSimultaneous) do
				local x = table.remove(pulseQ, 1)
				io.write(x.id, "\t", t, "\n")
			end
			tLast = t
		end

		t0 = t -- step clock

		return t

	end

	-- this one follows flip's idea but with early pulses
	local pulser_v4b = function(f)

		if f then
			if #f ~= n then
				error("length of f is wrong")
			end
			for i=1,n do
				o[i].f = f[i]
			end
			table.sort(o, function(a,b) return a.f>b.f end) -- sort by freq, descending
		end

		local t = time.clock() -- advance clock

		local dt = t - t0;

		-- what pulses are happening in this interval
		local qtmp = {}
		for i=1,n do
			local qnew = (o[i].qLast + dt*o[i].f*2*math.pi) % (2*math.pi) -- advance phase
			if qnew < o[i].qLast then -- gone over 2 pi boundary
				table.insert(qtmp, {f=o[i].f, id=o[i].id})
			end
			o[i].qLast = qnew -- update last phase
		end

		-- what pulses will happen in the next interval
		local qtmp2 = {}
		for i=1,n do
			local qnew = (o[i].qLast + dt*o[i].f*2*math.pi) % (2*math.pi)
			if qnew < o[i].qLast then
				table.insert(qtmp2, {f=o[i].f, id=o[i].id, qnew=qnew})
			end
			-- note dont update qLast ... yet
		end

		table.sort(qtmp, function(a,b) return a.f>b.f end) -- highest freq goes first

		if #qtmp == 0 and #qtmp2 > 1 then
			local fmin = math.huge
			local idx = nil
			for i=1,#qtmp2 do
				if fmin < qtmp2[i].f then
					idx = i
				end
			end
			local x = table.remove(qtmp2,idx)
			table.insert(qtmp, x)
			for i=1,n do
				if o[i].id == x.id then
					o[i].qLast = x.qnew
					break
				end
			end
		end

		pulseQ = table.merge(pulseQ, qtmp)

    	-- sort or shuffle pulseQ here
    	--pulseQ = table.permute(pulseQ)
    	--if #pulseQ < n/2 then
    	--	table.sort(pulseQ, function(a,b) return a.f>b.f end)
		--end

		-- Do I need to pulse and can I?
		if #pulseQ > 0 and (t-tLast) > dPulseT then
			for i=1,math.min(#pulseQ,numSimultaneous) do
				local x = table.remove(pulseQ, 1)
				io.write(x.id, "\t", t, "\n")
			end
			tLast = t
		end

		t0 = t -- step clock

		return t

	end

	return pulser_v4a

end

local freq = {20, 40, 55, 70, 90, 105, 125, 140,
	160, 175, 195, 210, 230, 245, 260, 280}

local p = make_pulsers(16, freq, 5e-4, 10)

-- need to be able to receive input over sockets
-- need to be able to send responses over parallel port

--collectgarbage("stop")

repeat
	t = p()
until t > 10
