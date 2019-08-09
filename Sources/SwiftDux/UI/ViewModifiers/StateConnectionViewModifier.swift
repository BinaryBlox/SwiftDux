import SwiftUI

internal struct NoUpdateAction : Action {}

/// A view modifier that injects a store into the environment.
internal struct StateConnectionViewModifier<Superstate, State> : ViewModifier {
  
  @EnvironmentObject private var superstateConnection: StateConnection<Superstate>
  @Environment(\.storeUpdated) private var storeUpdated
  @Environment(\.actionDispatcher) private var actionDispatcher
  
  private var filter: (Action)->Bool
  private var mapState: (Superstate)->State?

  internal init(filter: @escaping (Action)->Bool, mapState: @escaping (Superstate) -> State?) {
    self.filter = filter
    self.mapState = mapState
  }

  public func body(content: Content) -> some View {
    content
      .environmentObject(createDispatchConnection())
      .environmentObject(createStateConnection())
  }
  
  private func createStateConnection() -> StateConnection<State> {
    let hasUpdate = !filter(NoUpdateAction())
    let superGetState = superstateConnection.getState
    let stateConnection = StateConnection<State>(
      getState: { [mapState] in
        guard let superstate: Superstate = superGetState() else { return nil }
        return mapState(superstate)
      },
      changePublisher: hasUpdate ? storeUpdated.print().filter(filter).map { _ in }.eraseToAnyPublisher() : nil
    )
    return stateConnection
  }
  
  private func createDispatchConnection() -> DispatchConnection {
    DispatchConnection(actionDispatcher: actionDispatcher)
  }


}

extension View {
  
  /// Connect the application state to the UI.
  ///
  /// The returned mapped state is provided to the environment and accessible through the `MappedState` property wrapper.
  ///
  /// - Parameters
  ///   - updateWhen: Update the state when the closure returns true
  ///   - mapState: Maps a superstate to a substate.
  @available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
  public func connect<Superstate, State>(
    updateWhen filter: @escaping (Action)->Bool,
    mapState: @escaping (Superstate) -> State?
  ) -> some View {
    self.modifier(StateConnectionViewModifier(filter: filter, mapState: mapState))
  }
  
}