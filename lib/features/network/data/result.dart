/// Outcome of a single network call. Consumers switch exhaustively.
sealed class Result<T> {
  const Result();
}

final class Loading<T> extends Result<T> {
  const Loading();
}

final class Data<T> extends Result<T> {
  const Data(this.value);

  final T value;
}

final class Error<T> extends Result<T> {
  const Error(this.error);

  final Object error;
}

final class Offline<T> extends Result<T> {
  const Offline();
}
