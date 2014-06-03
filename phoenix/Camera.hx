package phoenix;


import lime.gl.GL;
import lime.gl.GLBuffer;
import lime.utils.Float32Array;

import phoenix.Matrix4;

import phoenix.Quaternion;
import phoenix.Rectangle;
import phoenix.Transform;
import phoenix.Vector;
import phoenix.Ray;

import luxe.options.CameraOptions;

enum ProjectionType {
    ortho;
    perspective;
    custom; 
}


class Camera {
    
    public var name : String = 'camera';    

    @:isVar public var viewport (get,set) : Rectangle;    
    @:isVar public var center (get,set) : Vector;
    @:isVar public var zoom (default,set) : Float = 1.0;

        //we keep a local pos variable as an unaltered position
        //to keep the center relative to the viewport, and allow setting position as 0,0 not center
    @:isVar public var pos (get,set) : Vector;
        //the other transforms defer directly to the transform so aren't variables
    public var scale (get,set) : Vector;
    public var rotation (get,set) : Quaternion;
    public var transform : Transform;

    public var minimum_zoom : Float = 0.01;
    public var projection_matrix : Matrix4;
    public var view_matrix : Matrix4;
    public var view_matrix_inverse : Matrix4;

    public var options : CameraOptions;
    public var perspective_options : ProjectionOptions;
    public var ortho_options : ProjectionOptions;
    public var projection : ProjectionType;

    public var target:Vector;
    public var up:Vector;

    @:noCompletion public var projection_float32array : Float32Array;
    @:noCompletion public var view_inverse_float32array : Float32Array;

        //A phoenix camera will default to ortho set to screen size        
    public function new( ?_options:CameraOptions ) {

        transform = new Transform();

            //save for later
        options = _options;

            //have sane defaults 
        if(options == null) {
            options = default_camera_options();
        }

            //store the name if any
        if(options.name != null) {
            name = options.name;
        }

            //default to ortho unless specified otherwise
        if(options.projection != null) {
            projection = options.projection;
        } else {
            projection = ProjectionType.ortho;
        }

            //default to screensize or use given viewport
        if(options.viewport != null) {
            viewport = options.viewport;            
        } else {
            viewport = new Rectangle( 0, 0, Luxe.screen.w, Luxe.screen.h );
        }

            //set the position/center explicitly so it can update the transform
        center = new Vector( viewport.w/2, viewport.h/2 );
        pos = new Vector();
        up = new Vector(0,1,0);
        
        projection_matrix = new Matrix4();
        view_matrix = new Matrix4();
        view_matrix_inverse = new Matrix4();

        ortho_options = default_ortho_options();
        perspective_options = default_perspective_options();

            //finally apply the projection specific defaults to the options
        apply_default_camera_options();

        switch (projection) {

            case ProjectionType.ortho:
                set_ortho( options );
            case ProjectionType.perspective:
                set_perspective( options );
            case ProjectionType.custom: {}
        }
        
    } //new 

    function apply_default_camera_options() {

        switch (projection) {

            case ProjectionType.ortho: {

                if(options.cull_backfaces == null) {
                    options.cull_backfaces = false;
                }

                if(options.depth_test == null) {
                    options.depth_test = false;
                }

            } //ortho

            case ProjectionType.perspective: {

                if(options.cull_backfaces == null) {
                    options.cull_backfaces = true;
                }

                if(options.depth_test == null) {
                    options.depth_test = true;
                }

            } //perspective

            case ProjectionType.custom: {}

        } //switch

    } //apply_default_camera_options
    function default_ortho_options() : ProjectionOptions {

        return {
            x1 : 0, 
            y1 : 0,
            x2 : Luxe.screen.w, 
            y2 : Luxe.screen.h,
            near : 1000, 
            far: -1000
        };

    } //default_ortho_options 

    function default_camera_options() : CameraOptions {

        return {
            projection : ProjectionType.ortho,
            depth_test : false,
            cull_backfaces : false,
            x1 : 0, 
            y1 : 0,
            x2 : Luxe.screen.w, 
            y2 : Luxe.screen.h,
            near : 1000, 
            far: -1000
        };

    } //default_camera_options 

    function default_perspective_options() : ProjectionOptions {

        return {
            fov : 60,
            aspect : 1.5,
            near : 0.1,
            far : 100
        };

    } //default_perspective_options
    
    public function process() {

        switch(projection) {
            case ProjectionType.perspective:
                apply_perspective();
            case ProjectionType.ortho:
                apply_ortho();
            case ProjectionType.custom: {}
        }

    } //process


    public function update_look_at() {

        var m1 = new Matrix4();
        
        m1.lookAt(target, pos, up);

        rotation.setFromRotationMatrix( m1 );

    } //update_look_at

    function update_view_matrix() {
            
            //:todo:#82: the float32array can be updated only when the transform changes
            //which will also need to happen for when the parent is dirty, so transform.dirty is not enough
        view_matrix = transform.world.matrix;
        view_matrix_inverse = view_matrix.inverse();

        view_inverse_float32array = view_matrix_inverse.float32array();

    } //update_view_matrix

    function update_projection_matrix() {
            
            //:todo:#82: This doesn't need to be rebuilt every frame

        switch(projection) {

            case ProjectionType.perspective:
                
                projection_matrix.makePerspective(perspective_options.fov, perspective_options.aspect, perspective_options.near, perspective_options.far );

            case ProjectionType.ortho:

                projection_matrix.makeOrthographic( 0, viewport.w, 0, viewport.h, ortho_options.near, ortho_options.far);

            case ProjectionType.custom: {}

        } //switch

        projection_float32array = projection_matrix.float32array();

    } //update_projection_matrix

    function apply_state(state:Int, value:Bool) {
        if(value) {
            Luxe.renderer.state.enable(state);
        } else {
            Luxe.renderer.state.disable(state);
        }
    } //apply_state

    public function apply_ortho() {

            //rebuild the projection matrix if needed
        update_projection_matrix();        
            //rebuild the view matrix if needed
        update_view_matrix();

            //apply states
        apply_state(GL.CULL_FACE, options.cull_backfaces);
        apply_state(GL.DEPTH_TEST, options.depth_test);
        
    } //apply_ortho

    public function apply_perspective() {

            //If we have a target, override the rotation BEFORE we update the matrix 
        if(target != null) {
            update_look_at();
        } //target not null
            
            //rebuild the projection matrix if needed
        update_projection_matrix();
            //rebuild the view matrix if needed
        update_view_matrix();

            //apply states
        apply_state(GL.CULL_FACE, options.cull_backfaces);
        apply_state(GL.DEPTH_TEST, options.depth_test);

    } //apply_perspective

    public function set_ortho( options:ProjectionOptions ) {
            
            //
        _merge_options( ortho_options, options );
            //
        projection = ProjectionType.ortho;
            //
        apply_ortho();

    } //set_ortho

    public function set_perspective( options:ProjectionOptions ) {

            //
        _merge_options( perspective_options, options );
            //
        projection = ProjectionType.perspective;
            //
        apply_perspective();

    } //set_perspective

        //from 3D to 2D
    public function project( _vector:Vector ) {

        update_view_matrix();

        var _transform = new Matrix4().multiplyMatrices( projection_matrix, view_matrix_inverse );
        return _vector.clone().applyProjection( _transform );

    } //project

        //from 2D to 3D 
    public function unproject( _vector:Vector ) {

        update_view_matrix();
        
        var _inverted = new Matrix4().multiplyMatrices( projection_matrix, view_matrix_inverse );
        return _vector.clone().applyProjection( _inverted.getInverse(_inverted) );

    } //unproject

    public function screen_point_to_ray( _vector:Vector ) : Ray {
        
        return new Ray( _vector, this );

    } //screen_point_as_ray

    public function screen_point_to_world( _vector:Vector ) : Vector {

        if( projection == ProjectionType.ortho ) {
            return ortho_screen_to_world(_vector);
        } else if( projection == ProjectionType.perspective ){
            return screen_point_to_ray( _vector ).end;
        }

            //given the default is ortho, for now
        return ortho_screen_to_world(_vector);

    } //screen_point_to_world

    public function world_point_to_screen( _vector:Vector, ?_viewport:Rectangle=null ) : Vector {

        if( projection == ProjectionType.ortho ) {
            return ortho_world_to_screen( _vector );
        } else if( projection == ProjectionType.perspective ) {
            return persepective_world_to_screen(_vector, _viewport);            
        }

            //given the default is ortho, for now
        return ortho_world_to_screen( _vector );

    } //world_point_to_screen

    function ortho_screen_to_world( _vector:Vector ) : Vector {

        update_view_matrix();

        return _vector.clone().applyMatrix4(view_matrix);

    } //ortho_screen_to_world

    function ortho_world_to_screen( _vector:Vector ) : Vector {

        update_view_matrix();

        return _vector.clone().applyMatrix4( view_matrix_inverse );

    } //ortho_world_to_screen

    function persepective_world_to_screen( _vector:Vector, ?_viewport:Rectangle=null ) {

        if(_viewport == null) { _viewport = viewport; }

        var _projected = project( _vector );
        
        var width_half = _viewport.w/2;
        var height_half = _viewport.h/2;

        return new Vector( 
             ( _projected.x * width_half ) + width_half, 
            -( _projected.y * height_half ) + height_half 
        );

    } //persepective_world_point_to_screen


        //0.5 = smaller , 2 = bigger
    function set_zoom( _z:Float ) : Float {

            //a temp value to manipulate
        var _new_zoom = _z;

            //new zoom value shouldn't be allowed beyond a minimum
            //but maybe this should be optional if you want negative zoom?
        if(_new_zoom < minimum_zoom) {
            _new_zoom = minimum_zoom;
        } 

        switch(projection) {

            case ProjectionType.ortho:

                    //scale the visual view based on the value
                transform.scale.x = 1/_new_zoom;
                transform.scale.y = 1/_new_zoom;
                    
            case ProjectionType.perspective: {

                // :todo: what happens when zooming perspective

            } 

            case ProjectionType.custom: {}
        
        } //switch projection


            //return the real value
        return zoom = _new_zoom;

    } //set_zoom

    function set_center( _p:Vector ) : Vector {

        switch(projection) {

            case ProjectionType.ortho:
                
                    //setting the center is the same as setting the position relative to the viewport
                pos = new Vector(_p.x - (viewport.w/2), _p.y - (viewport.h/2));
                    
            case ProjectionType.perspective: {}

            case ProjectionType.custom: {}
        
        } //switch projection

        return center = _p;

    } //set_center

    function get_center() : Vector {
        return center;
    } //get_center

    function get_pos() : Vector {
        return pos;
    } //get_pos
    
    function get_rotation() : Quaternion {
        return transform.rotation;
    } //get_rotation

    function get_scale() : Vector {
        return transform.scale;
    } //get_scale

    function get_viewport() : Rectangle {
        return viewport;
    } //get_viewport

    function set_viewport(_r:Rectangle) : Rectangle {

        viewport = _r;
        
        switch(projection) {

            case ProjectionType.ortho:                

                transform.origin = new Vector( _r.w/2, _r.h/2 );

                set_pos(pos == null ? new Vector() : pos);

            case ProjectionType.perspective: {}

            case ProjectionType.custom: {}
        
        } //switch projection

        return viewport;
    
    } //set_viewport

    function set_rotation( _q:Quaternion ) : Quaternion {
        return transform.rotation = _q;
    } //set_rotation

    function set_scale( _s:Vector ) : Vector {
        return transform.scale = _s;
    } //set_scale

    function set_pos( _p:Vector ) : Vector {

        switch(projection) {

            case ProjectionType.ortho:

                transform.pos.x = _p.x + (viewport.w/2);
                transform.pos.y = _p.y + (viewport.h/2);

            case ProjectionType.perspective: 

                transform.pos = pos = _p;

            case ProjectionType.custom: {}
        
        } //switch projection

        return pos;

    } //set_pos


    private function _merge_options( projection_options:ProjectionOptions, options:ProjectionOptions ) {

        if(options.aspect != null) {
            projection_options.aspect = options.aspect;
        }

        if(options.far != null) {
            projection_options.far = options.far;
        }

        if(options.fov != null) {
            projection_options.fov = options.fov;
        }

        if(options.near != null) {
            projection_options.near = options.near;
        }

        if(options.viewport != null) {
            projection_options.viewport = options.viewport;
        }

        if(options.x1 != null) {
            projection_options.x1 = options.x1;
        }

        if(options.x2 != null) {
            projection_options.x2 = options.x2;
        }

        if(options.y1 != null) {
            projection_options.y1 = options.y1;
        }

        if(options.y2 != null) {
            projection_options.y2 = options.y2;
        }

    } //_merge_options

} //Camera
