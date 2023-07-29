package main 

import scala.util.parsing.combinator.syntactical.StandardTokenParsers
import scala.util.parsing.input.Positional

sealed trait PositionExpr extends Positional

sealed trait Expr
object Expr {
    case class Condition(op: String, left: Expr, right: Expr) extends Expr 
    case class Number(value: Int) extends PositionalExpr
}

object Main extends App {

}

