import HmuxMobileRPC

enum SecondaryHostStatusAttempt {
    case received(MobileHostStatusResponse)
    case transientFailure
    case permanentFailure
}
