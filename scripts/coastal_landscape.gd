extends RefCounted
## Shared measurements for offline terrain authoring and route/collision validation.
const AIRPORT := Rect2(-4620,-650,2240,1350)
const OLD_NORTH := Rect2(-4200,-4500,6400,3500)

static func coast_z(x: float) -> float:
	var distance:=maxf(absf(x)-1500.0,0.0)
	return 800.0+smoothstep(0.0,1800.0,distance)*(650.0+sin(distance/1800.0)*260.0+sin(distance/5400.0)*430.0)

static func outside_distance(point: Vector2, area: Rect2) -> float:
	return Vector2(maxf(maxf(area.position.x-point.x,point.x-area.end.x),0),maxf(maxf(area.position.y-point.y,point.y-area.end.y),0)).length()

static func height_at(x: float, z: float) -> float:
	var p:=Vector2(x,z)
	var coast_distance:=coast_z(x)-z
	var city_distance:=outside_distance(p,Rect2(-1500,-1000,3000,1800))
	var hills:=18.0+13.0*sin(x/510.0)*cos(z/640.0)+9.0*sin(x/230.0+z/480.0)
	hills+=maxf(-z-5000.0,0.0)*0.017*(0.6+0.4*sin(x/1800.0))
	var height:=maxf(hills,2)*smoothstep(0,500,city_distance)*smoothstep(80,600,coast_distance)
	if coast_distance<80:
		height=lerpf(0.0,-2.0+maxf(coast_distance,0)*0.025,smoothstep(1500,1900,absf(x)))
	var north_blend:=1.0-smoothstep(0,350,outside_distance(p,OLD_NORTH))
	height=lerpf(height,-0.12,north_blend)
	var airport_blend:=1.0-smoothstep(0,180,outside_distance(p,AIRPORT))
	return lerpf(height,6.0,airport_blend)
