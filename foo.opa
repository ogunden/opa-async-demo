type state = {
  int value,
  bool do_server_call
}

function redraw(state) {
  #counter = state.value
}

@async server function server_call() {
  println("foo");
}

type message = {bool do_server_call} or {int increment} or {int setval}

client function message_handler(state state, message message) {
  match (message) {
  | {do_server_call:b} -> {
      state = { state with do_server_call:b };
      {set:state}
    }
  | {increment:by} -> {
      state = { state with value:state.value + by };
      redraw(state);
      if (state.do_server_call) {
        server_call();
      };
      {set:state}
    }
  | {setval:val} -> {
      state = { state with value:val };
      redraw(state);
      {set:state}
    }
  }
}

function handle_keypress(evt) {
  match (evt.key_code) {
  | {none} -> void
  | {some:kc} ->
    if (kc == 32 || kc == 43) {
      Session.send(get_chan(), {increment:1})
    } else if (kc == 45) {
      Session.send(get_chan(), {increment:-1})
    } else void
  }
}

function setup_keyboard() {
  eh =
    Dom.bind(Dom.select_document(), {keypress}, handle_keypress(_));
  ignore(eh)
}

client reference(option(channel(message))) ref = Reference.create({none})
function init_chan(initial_value) {
  match (Reference.get(ref)) {
  | {none} ->
      chan = Session.make(
        {value:initial_value, do_server_call:false}, message_handler)
      Reference.set(ref, {some:chan})
  | {some:_} -> error("initialized twice")
  }
}
function get_chan() {
  match (Reference.get(ref)) {
  | {none} -> error("get_chan returned none")
  | {some:c} -> c
  }
}

function initialize(initial_value) {
  init_chan(initial_value);
  setup_keyboard();
}

function servercall_checkbox() {
  do_server_call = Dom.is_checked(#servercall);
  Session.send(get_chan(), {~do_server_call})
}

function index() {
  initial_value = 2;
  <div onready={function(_) { initialize(initial_value) }}>
   <div id=#counter>{initial_value}</div>
   <a onclick={function(_) { Session.send(get_chan(), {increment:1}) }}
    >increment</a> (spacebar works too)
   <form options:onsubmit="prevent_default" action="javascript:null">
    <input type="checkbox" id=#servercall
      onchange={function (_) { servercall_checkbox()}}/>
        perform async server call each increment
      <br/>
    <input type="text" id=#setval size="4"/>
    <button onclick={function(_) {
      message = {setval:Int.of_string(Dom.get_value(#setval))};
      Session.send(get_chan(), message)
    }}>set value</button>
   </form>
  </div>
}

Server.start(Server.http, { title:"index", page:index })
