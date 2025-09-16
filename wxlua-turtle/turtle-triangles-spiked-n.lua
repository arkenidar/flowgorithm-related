-- for wxLua-based Turtle Graphics
require( "turtle" )
local function spiked( distance , sides )
  for i = 1 , sides do
    move( distance )
    turn( 360 / 2 )
    move( distance / 4 ) -- try 2 or 4 etc.
    turn( 360 / 2 )
    turn( -360 / sides )
  end
end
pncl( ranc() )
spiked( 100, 3 )
jump( -100 )
pncl( ranc() )
spiked( 100, 10 )
wait( )
