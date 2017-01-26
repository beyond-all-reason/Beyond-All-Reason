-- $Id: figures.lua 3171 2008-11-06 09:06:29Z det $
-------------------------------------------------------------------------------
-- Desc: Create a sphere centered at cy, cx, cz with radius r, and 
--       precision p. Based on a function Written by Paul Bourke. 
--       http://astronomy.swin.edu.au/~pbourke/opengl/sphere/
-------------------------------------------------------------------------------

local PI     = math.pi;
local TWOPI  = PI * 2;
local PIDIV2 = PI * 0.5;

local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_QUADS   = GL.QUADS
local glBeginEnd = gl.BeginEnd
local glNormal   = gl.Normal
local glTexCoord = gl.TexCoord
local glVertex   = gl.Vertex

local sin = math.sin
local cos = math.cos

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