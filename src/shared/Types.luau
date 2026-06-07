export type ClientInfo = {
	KeysPressed: { Enum.KeyCode? },
	MouseLocation: Vector2,
	State: "Pressed" | "Released",
}

export type StateMachine = {
	CurrentState: State?,
	LastState: State?,
	Queue: { State },
	Transition: (State) -> (),
	Clear: () -> (),
	Update: (number) -> (),
}

export type Entity = { Cooldowns: { [string]: boolean }, StateMachine: StateMachine, PlayerController: any }

type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
}

export type State = {
	OnEnter: () -> (),
	OnExit: () -> (),
	Update: (number) -> (),
	Extend: (State, number) -> State,
	Priority: number,
	Name: string,
	Elapsed: number,
	Duration: number?,
	At: number,
	StateMachine: StateMachine?,
}

return {}
