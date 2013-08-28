
if addon.InGetInfo then
	return {
		name    = "SpringLogo",
		desc    = "",
		author  = "jK",
		date    = "2012",
		license = "GPL2",
		layer   = 1,
		depend  = {"LoadProgress"},
		enabled = not true,
	}
end

------------------------------------------

local a = 0
local b = 0


local function DrawQuad(x, y, size)
	gl.Vertex(x - size, y - size, 0)
	gl.Vertex(x - size, y + size, 0)
	gl.Vertex(x + size, y + size, 0)
	gl.Vertex(x + size, y - size, 0)
end




local shader = gl.CreateShader({
	uniform = {
	},

	vertex = [[
	varying vec3 normal;
	varying vec4 color;
	varying vec3 color2;
	varying vec4 spos;
	varying vec4 mpos;
	varying float mirror;

	void main()
	{
		mirror = gl_FogCoord;
		color = gl_Color;
		color2 = gl_SecondaryColor.rgb;
		normal = gl_NormalMatrix * gl_Normal;
		spos = gl_ModelViewMatrix * gl_Vertex;
		mpos = gl_ModelViewMatrix * (gl_Vertex * vec4(1.0,1.0,mirror,1.0) - vec4(0.0,0.0,-2.0 * step(0.5, -mirror),0.0));
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
	}
	]],

	fragment = [[
	varying vec3 normal;
	varying vec4 color;
	varying vec3 color2;
	varying vec4 spos;
	varying vec4 mpos;
	varying float mirror;

	float sqlength(vec3 v)
	{
		return dot(v,v);
	}

	void main()
	{
		vec3 light = normalize(spos - gl_LightSource[0].position.xyz);
		vec3 n = normalize(normal);

		float ambient = 0.45;
		float diffuse = max(0.0, dot(n,light));

		vec3 light2 = normalize(spos - gl_LightSource[1].position.xyz);
		float diffuse2 = sqlength(spos - gl_LightSource[1].position.xyz) * 2.5;
		diffuse2 = 1.0 - min(1.0, diffuse2);
		//diffuse2 *= max(0.0, dot(n,light2));

		vec3 light2Pos = gl_LightSource[2].position.xyz;
		vec3 light2Dir = normalize(light2Pos - spos);
		vec3 r = reflect(-light2Dir, n);
		vec3 v = -normalize(spos);

		float specular1 = 0.75 * pow(max(0.0, dot(r, v)), 1.3);
		float specular2 = 0.80 * pow(max(0.0, dot(r, v)), 4.0);
		float specular3 = 0.40 * pow(max(0.0, dot(r, v)), 7.0);

		gl_FragColor.a = 1.0;
		gl_FragColor.rgb = color.rgb * (ambient + diffuse);

		gl_FragColor.rgb += color.rrr * vec3(1.2, 0.0, 0.0) * diffuse2;
		gl_FragColor.rgb += color.rrr * 0.65 * vec3(0.0, 0.9, 0.9) * pow(diffuse2, 1.5);

		gl_FragColor.rgb += color.bbb * 0.1 * vec3(0.5, 0.5, 1.5) * diffuse2;
		gl_FragColor.rgb += color.bbb * 0.5 * vec3(0.5, 0.5, 1.0) * pow(diffuse2, 1.5);

		gl_FragColor.rgb += color.rgb * vec3(1.0, 1.0, 0.5) * 1.5 * specular1;
		gl_FragColor.rgb += vec3(1.0, 1.0, 0.7) * (specular2 + specular3);
		gl_FragColor.rgb += color2; //shiness

		// sun coloring
		float cubeCenterDist = length(mpos.xyz - gl_LightSource[3].position.xyz);
		gl_FragColor.rgb += step(0.1,color.rrr) * vec3(1.0, 1.0, 0.0) * smoothstep(1.2, 0.1, cubeCenterDist * 2.4);
		gl_FragColor.rgb -= step(0.1,color2.rrr) * vec3(0.0, 0.0, 0.5) * smoothstep(0.7, 1.6, cubeCenterDist * 2.6);

		if (mirror < 0.0) {
			//FIXME
			float depth = dot(spos, gl_LightSource[4].position.xyz);
			float a = clamp(depth * 3.0, 0.0, 1.0);
			gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(1.0), a);
		}

		// gamma
		//gl_FragColor.rgb = pow(gl_FragColor.rgb, vec3(1.0 / 0.9));
	}
	]],
})

Spring.Echo(gl.GetShaderLog())









function SIGN(x)
	return ((x >= 0) and 1) or -1
end

function EvalSuperEllipse(t1,t2,p1,p2)
	local ct1 = math.cos(t1);
	local ct2 = math.cos(t2);
	local st1 = math.sin(t1);
	local st2 = math.sin(t2);

	local tmp  = SIGN(ct1) * math.pow(math.abs(ct1),p1);
	local x = tmp * SIGN(ct2) * math.pow(math.abs(ct2),p2);
	local y =       SIGN(st1) * math.pow(math.abs(st1),p1);
	local z = tmp * SIGN(st2) * math.pow(math.abs(st2),p2);

	return x,y,z
end

function CalcNormal(px,py,pz, p1x,p1y,p1z, p2x,p2y,p2z)
	local pax = p1x - px;
	local pay = p1y - py;
	local paz = p1z - pz;
	local pbx = p2x - px;
	local pby = p2y - py;
	local pbz = p2z - pz;
	local nx = pay * pbz - paz * pby;
	local ny = paz * pbx - pax * pbz;
	local nz = pax * pby - pay * pbx;
	local l = math.sqrt(nx*nx + ny*ny + nz*nz);

	if (l == 0) then
		return 0, 1, 0;
	end
	return nx/l, ny/l, nz/l;
end

function CreateSuperEllipse(power1,power2,n)
	--http://paulbourke.net/geometry/superellipse/
	local PID2  = math.pi / 2
	local TWOPI = 2 * math.pi
	local delta = 0.01 * TWOPI / n;
	local j = 0
	while (j < n/2) do
		local theta1 = (j * TWOPI / n) - PID2;
		local theta2 = ((j + 1) * TWOPI / n) - PID2;

		gl.BeginEnd(GL.TRIANGLE_STRIP, function()
			local i = 0
			while (i <= n) do
				local theta3 = i * TWOPI / n;

				if (j == n/2 - 1) then
					local px,py,pz    = EvalSuperEllipse(theta2        , 0        , power1, power2);
					local p1x,p1y,p1z = EvalSuperEllipse(theta2        , 0 + delta, power1, power2);
					local p2x,p2y,p2z = EvalSuperEllipse(theta2 + delta, 0 + delta, power1, power2);
					local nx,ny,nz = CalcNormal(p1x,p1y,p1z, px,py,pz, p2x,p2y,p2z);
					gl.Normal(nx,ny,nz);
					gl.TexCoord(i/n,2*(j+1)/n);
					gl.Vertex(px,py,pz);
				else
					local px,py,pz    = EvalSuperEllipse(theta2        , theta3        , power1, power2);
					local p1x,p1y,p1z = EvalSuperEllipse(theta2 + delta, theta3        , power1, power2);
					local p2x,p2y,p2z = EvalSuperEllipse(theta2        , theta3 + delta, power1, power2);
					local nx,ny,nz = CalcNormal(p1x,p1y,p1z, px,py,pz, p2x,p2y,p2z);
					gl.Normal(nx,ny,nz);
					gl.TexCoord(i/n,2*(j+1)/n);
					gl.Vertex(px,py,pz);
				end

				if (j == 0) then
					local px,py,pz    = EvalSuperEllipse(theta1        , 0        , power1, power2);
					local p1x,p1y,p1z = EvalSuperEllipse(theta1        , 0 + delta, power1, power2);
					local p2x,p2y,p2z = EvalSuperEllipse(theta1 + delta, 0 + delta, power1, power2);
					local nx,ny,nz = CalcNormal(p1x,p1y,p1z, px,py,pz, p2x,p2y,p2z);
					gl.Normal(nx,ny,nz);
					gl.TexCoord(i/n,2*j/n);
					gl.Vertex(px,py,pz);
				else
					local px,py,pz    = EvalSuperEllipse(theta1        , theta3        , power1, power2);
					local p1x,p1y,p1z = EvalSuperEllipse(theta1 + delta, theta3        , power1, power2);
					local p2x,p2y,p2z = EvalSuperEllipse(theta1        , theta3 + delta, power1, power2);
					local nx,ny,nz = CalcNormal(p1x,p1y,p1z, px,py,pz, p2x,p2y,p2z);
					gl.Normal(nx,ny,nz);
					gl.TexCoord(i/n,2*j/n);
					gl.Vertex(px,py,pz);
				end

				i = i + 1
			end
		end)
		j = j + 1
	end
end

function blend(x1,x2,a)
	return a * x2 + (1 - a) * x1
end


function GetSunVertex(r,theta)
	local a = math.pi / 10

	local theta1 = math.floor(theta / a) * a
	local theta2 = theta1 + a

	local s = (theta - theta1) / (theta2 - theta1)
	--local s = (theta % a) / a
	s = math.min(1, math.max(0, s))

	local u = math.floor(theta / a) % 2
	local r1 = (u >= 1.0) and 1 or 0
	local r2 = (u <= 0.5) and 1 or 0

	local t1x = r * (r1 * 0.4 + 0.6) * math.cos(theta1)
	local t1y = r * (r1 * 0.4 + 0.6) * math.sin(theta1)
	local t2x = r * (r2 * 0.4 + 0.6) * math.cos(theta2)
	local t2y = r * (r2 * 0.4 + 0.6) * math.sin(theta2)

	return blend(t1x, t2x, s), -blend(t1y, t2y, s)
end


function DrawSun()
	local n = 150
	local TWOPI = 2 * math.pi
	gl.BeginEnd(GL.TRIANGLE_STRIP, function()
		gl.Normal(0, -1, 0);
		local i = 0
		while (i <= n) do
			local theta = i * TWOPI / n;
			local r = 0.8

			if (theta == TWOPI) then
				gl.Normal(0, 0, -1);
				gl.Vertex(r * 0.5 * math.cos(math.pi - (theta - math.pi)), 1.15, -r * 0.5 * math.sin(math.pi - (theta - math.pi)));
				gl.Vertex(r * 0.5 * math.cos(math.pi - (theta - math.pi)), 0.80, -r * 0.5 * math.sin(math.pi - (theta - math.pi)));
			end

			if (theta <= math.pi)or(theta == TWOPI) then
				local vx, vy = GetSunVertex(r, theta)

				--gl.Color(s, 0, 0, 1);
				if (theta == TWOPI)or(theta == math.pi) then
					gl.Normal(0, 0, -1);
				else
					local vxp1, vyp1 = GetSunVertex(r, theta + 0.0001 * math.pi)
					local vxm1, vym1 = GetSunVertex(r, theta - 0.0001 * math.pi)
					local nxp1,nyp1,nzp1 = CalcNormal(vxp1,0,vyp1, vx,0,vy, vx,1,vy);
					local nxm1,nym1,nzm1 = CalcNormal(vxm1,0,vym1, vx,1,vy, vx,0,vy);
					local nx,ny,nz = nxp1 + nxm1, nyp1 + nym1, nzp1 + nzm1
					gl.Normal(nx,ny,nz);
				end
				gl.Vertex(vx, 1.15, vy);
				gl.Vertex(vx, 0.80, vy);
			end

			if (theta >= math.pi)and(theta ~= TWOPI) then
				if (theta == math.pi) then
					gl.Normal(0, 0, -1);
				else
					gl.Normal(math.cos(theta), 0, math.sin(theta));
				end
				gl.Vertex(r * 0.5 * math.cos(math.pi - (theta - math.pi)), 1.15, -r * 0.5 * math.sin(math.pi - (theta - math.pi)));
				gl.Vertex(r * 0.5 * math.cos(math.pi - (theta - math.pi)), 0.80, -r * 0.5 * math.sin(math.pi - (theta - math.pi)));
			end

			i = i + 1
		end
	end)

	gl.BeginEnd(GL.TRIANGLE_STRIP, function()
		gl.Normal(0, -1, 0);

		local i = 0
		while (i <= n/2) do
			local theta = i * TWOPI / n;
			local r = 0.8

			if (theta <= math.pi) then
				local vx, vy = GetSunVertex(r, theta)
				gl.Vertex(vx, 1.15, vy);
			end

			gl.Vertex(r * 0.5 * math.cos(theta), 1.15, -r * 0.5 * math.sin(theta));
			i = i + 1
		end
	end)
end



local cube_dl


function DrawLogo()
	if (cube_dl) then
		gl.CallList(cube_dl)
		return
	end

	cube_dl = gl.CreateList(function()
		gl.PushMatrix()
		gl.SecondaryColor(0, 0, 0) --// shiness
		local b = 1.0
		gl.Color(b*18/255, b*30/255, b*80/255, 1)
		CreateSuperEllipse(0.16, 0.16, 50)

		gl.Translate(0, 0.17, 0)
		gl.Scale(0.85,0.85,0.85)
		gl.Color(112/255, 32/255, 24/255, 1)
		CreateSuperEllipse(0.09, 0.09, 50)

		gl.Culling(false)

		--gl.Translate(0, -0.14, 0.22)
		gl.Translate(0, -0.097, 0.22)
		local t = 0.3
		gl.Color(1*t, 1*t, 0.7*t, 1)
		t = 1.00
		gl.SecondaryColor(1*t, 1*t, 0.45*t)
		DrawSun()
		gl.SecondaryColor(1, 1, 1)
		gl.PopMatrix()
	end)
end




function addon.DrawLoadScreen()
	local loadProgress = SG.GetLoadProgress()

	--b = math.min(b + 0.0005, 1.0)
	a = (a + 0.001)
	b = math.sin(a) * 20.0
	--b = math.sin(a) * 180.0

	local vsx, vsy = gl.GetViewSizes()

	gl.MatrixMode(GL.PROJECTION)
	gl.PushMatrix()
	gl.LoadIdentity()
	local fH = math.tan( 45 / 360 * math.pi ) * 1;
	local fW = fH * (vsx/vsy);
	gl.Frustum(-fW, fW, -fH, fH, 1, 5)

	gl.MatrixMode(GL.MODELVIEW)
	gl.PushMatrix()
	gl.LoadIdentity()

	gl.Translate(0,0,-2)
	gl.Scale(1/3,1/3,1/3)

	--gl.MatrixMode(GL.TEXTURE)
	--gl.LoadIdentity()

	gl.Rotate((b*0.1)+10, 1,0,0)
	gl.Rotate(b+5, 0,1,0)
	gl.Rotate(90, 1,0,0)

	--Note, lightPos is automatically multiplied with _current_ ModelViewMatrix!!!
	gl.Light(0, GL.POSITION, -4, 4, -4, 1)
	gl.Light(1, GL.POSITION, -0.25, 2, -0.6, 1)
	gl.Light(2, GL.POSITION, -20, 1, -15, 1)
	gl.Light(3, GL.POSITION, 0, 0, 0, 1)
	gl.Light(4, GL.POSITION, 0, 0, 1, 0)

	gl.UseShader(shader)
	gl.Culling(GL.FRONT)
	gl.DepthTest(true)
	gl.DepthMask(true)

	gl.FogCoord(1)
	DrawLogo()

	gl.FogCoord(-1)
	gl.Translate(0,0,2)
	gl.Culling(GL.BACK)
	gl.Scale(1,1,-1)
	DrawLogo()

	gl.DepthTest(false)
	gl.UseShader(0)
	gl.MatrixMode(GL.PROJECTION)
	gl.PopMatrix()
	gl.MatrixMode(GL.MODELVIEW)
	gl.PopMatrix()
end
