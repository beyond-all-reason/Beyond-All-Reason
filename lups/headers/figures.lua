-------------------------------------------------------------------------------
-- Desc: Create a sphere centered at cy, cx, cz with radius r, and
--       precision p. Based on a function Written by Paul Bourke.
--       http://astronomy.swin.edu.au/~pbourke/opengl/sphere/
-------------------------------------------------------------------------------

local PI     = math.pi;
local TWOPI  = PI * 2;
local PIDIV2 = PI * 0.5;

local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local glBeginEnd = gl.BeginEnd
local glNormal   = gl.Normal
local glTexCoord = gl.TexCoord
local glVertex   = gl.Vertex

local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt

function DrawSphere( cx, cy, cz, r, p )
    local theta1,theta2,theta3 = 0,0,0;
    local ex,ey,ez = 0,0,0;
    local px,py,pz = 0,0,0;

    --// Disallow a negative number for radius.
    if ( r < 0 ) then r = -r; end

    --// Disallow a negative number for precision.
    if ( p < 0 ) then p = -p; end

    for i = 0,p*0.5-1 do
        theta1 = i * TWOPI / p - PIDIV2;
        theta2 = (i + 1) * TWOPI / p - PIDIV2;

        glBeginEnd( GL_TRIANGLE_STRIP , function()
            for j = 0,p do
                theta3 = j * TWOPI / p;

                ex = cos(theta2) * cos(theta3);
                ey = sin(theta2);
                ez = cos(theta2) * sin(theta3);
                px = cx + r * ex;
                py = cy + r * ey;
                pz = cz + r * ez;

                glNormal( ex, ey, ez );
                glTexCoord( -(j/p) , 2*(i+1)/p );
                glVertex( px, py, pz );

                ex = cos(theta1) * cos(theta3);
                ey = sin(theta1);
                ez = cos(theta1) * sin(theta3);
                px = cx + r * ex;
                py = cy + r * ey;
                pz = cz + r * ez;

                glNormal( ex, ey, ez );
                glTexCoord( -(j/p), 2*i/p );
                glVertex( px, py, pz );
            end
        end)
    end
end

-- http://www.glprogramming.com/red/chapter02.html
function DrawIcosahedron(subd, cw)
	local function normalize(vertex)
		r = sqrt(vertex[1]*vertex[1] + vertex[2]*vertex[2] + vertex[3]*vertex[3])
		vertex[1], vertex[2], vertex[3] = vertex[1] / r, vertex[2] / r, vertex[3] / r
		return vertex
	end

	local function midpoint(pt1, pt2)
		return { (pt1[1] + pt2[1]) / 2, (pt1[2] + pt2[2]) / 2, (pt1[3] + pt2[3]) / 2}
	end

	local function subdivide(pt1, pt2, pt3)
		pt12 = normalize(midpoint(pt1, pt2))
		pt13 = normalize(midpoint(pt1, pt3))
		pt23 = normalize(midpoint(pt2, pt3))

		-- CCW order, starting from leftmost
		return {
			{pt12, pt13, pt1},
			{pt2, pt23, pt12},
			{pt12, pt23, pt13},
			{pt23, pt3, pt13},
		}
	end

	local function GetSphericalUV(f)
		local u = math.atan2(f[3], f[1]) / math.pi -- [-0.5 <--> 0.5]
		local v = math.acos(f[2]) / math.pi --[0 <--> 1]
		return u * 0.5 + 0.5, 1.0 - v -- TODO check the last one
	end

	--------------------------------------------

	local X = 1
	local Z = (1 + sqrt(5)) / 2

	local vertexes0 = {
		{-X, 0.0, Z}, {X, 0.0, Z}, {-X, 0.0, -Z}, {X, 0.0, -Z},
		{0.0, Z, X}, {0.0, Z, -X}, {0.0, -Z, X}, {0.0, -Z, -X},
		{Z, X, 0.0}, {-Z, X, 0.0}, {Z, -X, 0.0}, {-Z, -X, 0.0},
	}

	for _, vert in ipairs(vertexes0) do
		vert = normalize(vert)
	end

	local fi0 = {
		{1,5,2}, {1,10,5}, {10,6,5}, {5,6,9}, {5,9,2},
		{9,11,2}, {9,4,11}, {6,4,9}, {6,3,4}, {3,8,4},
		{8,11,4}, {8,7,11}, {8,12,7}, {12,1,7}, {1,2,7},
		{7,2,11}, {10,1,12}, {10,12,3}, {10,3,6}, {8,3,12},
	}


	if cw then -- re-wind to clockwise order
		for i = 1, #fi0 do
			fi0[i][2], fi0[i][3] = fi0[i][3], fi0[i][2]
		end
	end

	local faces0 = {}
	for i = 1, #fi0 do
		faces0[i] = {vertexes0[fi0[i][1]], vertexes0[fi0[i][2]], vertexes0[fi0[i][3]]}
	end


	local faces = faces0

	subd = subd or 1

	for s = 2, subd do
		newfaces = {}
		for fii = 1, #faces do
			local newsub = subdivide(faces[fii][1], faces[fii][2], faces[fii][3])
			for _, tri in ipairs(newsub) do
				table.insert(newfaces, tri)
			end
		end
		faces = newfaces
	end

	gl.BeginEnd(GL.TRIANGLES , function()
		for _, face in ipairs(faces) do
			gl.TexCoord( GetSphericalUV(face[1]) );
			gl.Normal(face[1][1], face[1][2], face[1][3])
			gl.Vertex(face[1][1], face[1][2], face[1][3])

			gl.TexCoord( GetSphericalUV(face[2]) );
			gl.Normal(face[2][1], face[2][2], face[2][3])
			gl.Vertex(face[2][1], face[2][2], face[2][3])

			gl.TexCoord( GetSphericalUV(face[3]) );
			gl.Normal(face[3][1], face[3][2], face[3][3])
			gl.Vertex(face[3][1], face[3][2], face[3][3])
		end
	end)
end

--
-- not finished
--
function DrawCylinder( cx, cy, cz, r, h, p )
    local theta1,theta2,theta3 = 0,0,0;
    local ex,ey,ez = 0,0,0;
    local px,py,pz = 0,0,0;

    --// Disallow a negative number for radius.
    if ( r < 0 ) then r = -r; end

    --// Disallow a negative number for precision.
    if ( p < 0 ) then p = -p; end

    glBeginEnd( GL_TRIANGLE_STRIP , function()
    for i = 0,p do
        theta1 = i * TWOPI / p;
        --theta2 = (i + 1) * TWOPI / p;
                ex = sin(theta1);
                ez = cos(theta1);
                px = cx + r * ex;
                py = cy;
                pz = cz + r * ez;

                glNormal( ex, 1, ez );
                glTexCoord( i/p , 0 );
                glVertex( px, py, pz );

                py = cy + h;

                glTexCoord( i/p, 1 );
                glVertex( px, py, pz );
    end
    end)
end


--
-- miss Normals,TexCoords
--
function DrawPin(r, h, divs )
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
      glNormal( 0, 1, 0 );
      glTexCoord( 0.5 , 0 );
      glVertex( 0, h,  0)
      for i = 0, divs do
        local a = i * ((math.pi * 2) / divs)
        local cosval = math.cos(a)
        local sinval = math.sin(a)
        glNormal( sinval, h, cosval );
        glTexCoord( i/divs , 1 );
        glVertex( r * sinval, 0, r * cosval )
      end
    end)
end



--
-- Draw a torus
--
function DrawTorus(r,R,numc,numt)
   local cTwoPi = TWOPI/numc
   local tTwoPi = TWOPI/numt

   local a = 0.5*(R-r)
   local c = 0.5*(R+r)

   for i=0,numc do
      gl.BeginEnd(GL.QUAD_STRIP, function ()
        for j=0,numt do
           for k=1,0,-1 do
              local s = ((i + k) % numc + 0.5)*cTwoPi;
              local t = (j % numt)*tTwoPi;

              local x = (c+a*cos(s))*cos(t);
              local z = (c+a*cos(s))*sin(t);
              local y = a*sin(s);
              gl.Normal( -cos(s)*cos(t), -sin(s), -cos(s)*sin(t) );
              gl.Vertex( x, y, z );
           end
        end
      end)
   end
end